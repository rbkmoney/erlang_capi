-module(capi_handler_payments).

-include_lib("dmsl/include/dmsl_payment_processing_thrift.hrl").
-include_lib("dmsl/include/dmsl_domain_thrift.hrl").

-behaviour(capi_handler).
-export([process_request/3]).
-import(capi_handler_utils, [general_error/2, logic_error/3]).

-spec process_request(
    OperationID :: capi_handler:operation_id(),
    Req         :: capi_handler:request_data(),
    Context     :: capi_handler:processing_context()
) ->
    {ok | error, capi_handler:response() | noimpl}.

process_request('CreatePayment', Req, Context) ->
    InvoiceID = maps:get('invoiceID', Req),
    PaymentParams = maps:get('PaymentParams', Req),
    Flow = genlib_map:get(<<"flow">>, PaymentParams, #{<<"type">> => <<"PaymentFlowInstant">>}),
    Result =
        try
            Params =  #payproc_InvoicePaymentParams{
                'payer' = encode_payer_params(genlib_map:get(<<"payer">>, PaymentParams)),
                'flow' = encode_flow(Flow),
                'make_recurrent' = genlib_map:get(<<"makeRecurrent">>, PaymentParams, false)
            },
            Call = {invoicing, 'StartPayment', [InvoiceID, Params]},
            capi_handler_utils:service_call_with([user_info], Call, Context)
        catch
            throw:Error when
                Error =:= invalid_token orelse
                Error =:= invalid_payment_session
            ->
                {error, Error}
        end,

    case Result of
        {ok, Payment} ->
            {ok, {201, [], decode_invoice_payment(InvoiceID, Payment, Context)}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvalidInvoiceStatus{} ->
                    {ok, logic_error(400, invalidInvoiceStatus, <<"Invalid invoice status">>)};
                #payproc_InvoicePaymentPending{} ->
                    ErrorResp = logic_error(
                        400,
                        invoicePaymentPending,
                        <<"Invoice payment pending">>
                    ),
                    {ok, ErrorResp};
                #'InvalidRequest'{errors = Errors} ->
                    FormattedErrors = capi_handler_utils:format_request_errors(Errors),
                    {ok, logic_error(400, invalidRequest, FormattedErrors)};
                #payproc_InvalidPartyStatus{} ->
                    {ok, logic_error(400, invalidPartyStatus, <<"Invalid party status">>)};
                #payproc_InvalidShopStatus{} ->
                    {ok, logic_error(400, invalidShopStatus, <<"Invalid shop status">>)};
                #payproc_InvalidContractStatus{} ->
                    ErrorResp = logic_error(
                        400,
                        invalidContractStatus,
                        <<"Invalid contract status">>
                    ),
                    {ok, ErrorResp};
                #payproc_InvalidRecurrentParentPayment{} ->
                    ErrorResp = logic_error(
                        400,
                        invalidRecurrentParent,
                        <<"Specified recurrent parent is invalid">>
                    ),
                    {ok, ErrorResp};
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)}
            end;
        {error, invalid_token} ->
            {ok, logic_error(400,
                invalidPaymentToolToken,
                <<"Specified payment tool token is invalid">>
            )};
        {error, invalid_payment_session} ->
            {ok, logic_error(400,
                invalidPaymentSession,
                <<"Specified payment session is invalid">>
            )}
    end;

process_request('GetPayments', Req, Context) ->
    InvoiceID = maps:get(invoiceID, Req),
    case capi_handler_utils:get_invoice_by_id(InvoiceID, Context) of
        {ok, #'payproc_Invoice'{payments = Payments}} ->
            {ok, {200, [], [decode_invoice_payment(InvoiceID, P, Context) || P <- Payments]}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)}
            end
    end;

process_request('GetPaymentByID', Req, Context) ->
    InvoiceID = maps:get(invoiceID, Req),
    case capi_handler_utils:get_payment_by_id(InvoiceID, maps:get(paymentID, Req), Context) of
        {ok, Payment} ->
            {ok, {200, [], decode_invoice_payment(InvoiceID, Payment, Context)}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvoicePaymentNotFound{} ->
                    {ok, general_error(404, <<"Payment not found">>)};
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)}
            end
    end;

process_request('CancelPayment', Req, Context) ->
    CallArgs = [maps:get(invoiceID, Req), maps:get(paymentID, Req), maps:get(<<"reason">>, maps:get('Reason', Req))],
    Call = {invoicing, 'CancelPayment', CallArgs},
    case capi_handler_utils:service_call_with([user_info], Call, Context) of
        {ok, _} ->
            {ok, {202, [], undefined}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvoicePaymentNotFound{} ->
                    {ok, general_error(404, <<"Payment not found">>)};
                #payproc_InvalidPaymentStatus{} ->
                    {ok, logic_error(400, invalidPaymentStatus, <<"Invalid payment status">>)};
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #'InvalidRequest'{errors = Errors} ->
                    FormattedErrors = capi_handler_utils:format_request_errors(Errors),
                    {ok, logic_error(400, invalidRequest, FormattedErrors)};
                #payproc_OperationNotPermitted{} ->
                    ErrorResp = logic_error(
                        400,
                        operationNotPermitted,
                        <<"Operation not permitted">>
                    ),
                    {ok, ErrorResp};
                #payproc_InvalidPartyStatus{} ->
                    {ok, logic_error(400, invalidPartyStatus, <<"Invalid party status">>)};
                #payproc_InvalidShopStatus{} ->
                    {ok, logic_error(400, invalidShopStatus, <<"Invalid shop status">>)}
            end
    end;

process_request('CapturePayment', Req, Context) ->
    CallArgs = [maps:get(invoiceID, Req), maps:get(paymentID, Req), maps:get(<<"reason">>, maps:get('Reason', Req))],
    Call = {invoicing, 'CapturePayment', CallArgs},
    case capi_handler_utils:service_call_with([user_info], Call, Context) of
        {ok, _} ->
            {ok, {202, [], undefined}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvoicePaymentNotFound{} ->
                    {ok, general_error(404, <<"Payment not found">>)};
                #payproc_InvalidPaymentStatus{} ->
                    {ok, logic_error(400, invalidPaymentStatus, <<"Invalid payment status">>)};
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #'InvalidRequest'{errors = Errors} ->
                    FormattedErrors = capi_handler_utils:format_request_errors(Errors),
                    {ok, logic_error(400, invalidRequest, FormattedErrors)};
                #payproc_OperationNotPermitted{} ->
                    ErrorResp = logic_error(
                        400,
                        operationNotPermitted,
                        <<"Operation not permitted">>
                    ),
                    {ok, ErrorResp};
                #payproc_InvalidPartyStatus{} ->
                    {ok, logic_error(400, invalidPartyStatus, <<"Invalid party status">>)};
                #payproc_InvalidShopStatus{} ->
                    {ok, logic_error(400, invalidShopStatus, <<"Invalid shop status">>)}
            end
    end;

process_request('CreateRefund', Req, Context) ->
    InvoiceID = maps:get(invoiceID, Req),
    PaymentID = maps:get(paymentID, Req),
    RefundParams = maps:get('RefundParams', Req),
    Params = #payproc_InvoicePaymentRefundParams{
        reason = genlib_map:get(<<"reason">>, RefundParams),
        cash = encode_optional_refund_cash(RefundParams, InvoiceID, PaymentID, Context)
    },
    Call = {invoicing, 'RefundPayment', [InvoiceID, PaymentID, Params]},
    case capi_handler_utils:service_call_with([user_info], Call, Context) of
        {ok, Refund} ->
            {ok, {201, [], capi_handler_decoder_invoicing:decode_refund(Refund, Context)}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvoicePaymentNotFound{} ->
                    {ok, general_error(404, <<"Payment not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvalidPartyStatus{} ->
                    {ok, logic_error(400, invalidPartyStatus, <<"Invalid party status">>)};
                #payproc_InvalidShopStatus{} ->
                    {ok, logic_error(400, invalidShopStatus, <<"Invalid shop status">>)};
                #payproc_InvalidContractStatus{} ->
                    ErrorResp = logic_error(
                        400,
                        invalidContractStatus,
                         <<"Invalid contract status">>
                    ),
                    {ok, ErrorResp};
                #payproc_OperationNotPermitted{} ->
                    ErrorResp = logic_error(
                        400,
                        operationNotPermitted,
                        <<"Operation not permitted">>
                    ),
                    {ok, ErrorResp};
                #payproc_InvalidPaymentStatus{} ->
                    ErrorResp = logic_error(
                        400,
                        invalidPaymentStatus,
                        <<"Invalid invoice payment status">>
                    ),
                    {ok, ErrorResp};
                #payproc_InsufficientAccountBalance{} ->
                    {ok, logic_error(
                        400,
                        insufficentAccountBalance,
                        <<"Operation can not be conducted because of insufficient funds on the merchant account">>
                    )};
                #payproc_InvoicePaymentAmountExceeded{} ->
                    ErrorResp = logic_error(
                        400,
                        invoicePaymentAmountExceeded,
                        <<"Payment amount exceeded">>
                    ),
                    {ok, ErrorResp};
                #payproc_InconsistentRefundCurrency{} ->
                    ErrorResp = logic_error(
                        400,
                        inconsistentRefundCurrency,
                        <<"Inconsistent refund currency">>
                    ),
                    {ok, ErrorResp};
                #'InvalidRequest'{errors = Errors} ->
                    FormattedErrors = capi_handler_utils:format_request_errors(Errors),
                    {ok, logic_error(400, invalidRequest, FormattedErrors)}
            end
    end;

process_request('GetRefunds', Req, Context) ->
    case capi_handler_utils:get_payment_by_id(maps:get(invoiceID, Req), maps:get(paymentID, Req), Context) of
        {ok, #payproc_InvoicePayment{refunds = Refunds}} ->
            {ok, {200, [], [capi_handler_decoder_invoicing:decode_refund(R, Context) || R <- Refunds]}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvoicePaymentNotFound{} ->
                    {ok, general_error(404, <<"Payment not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)}
            end
    end;

process_request('GetRefundByID', Req, Context) ->
    Call =
        {invoicing, 'GetPaymentRefund', [maps:get(invoiceID, Req), maps:get(paymentID, Req), maps:get(refundID, Req)]},
    case capi_handler_utils:service_call_with([user_info], Call, Context) of
        {ok, Refund} ->
            {ok, {200, [], capi_handler_decoder_invoicing:decode_refund(Refund, Context)}};
        {exception, Exception} ->
            case Exception of
                #payproc_InvoicePaymentRefundNotFound{} ->
                    {ok, general_error(404, <<"Invoice payment refund not found">>)};
                #payproc_InvoicePaymentNotFound{} ->
                    {ok, general_error(404, <<"Payment not found">>)};
                #payproc_InvoiceNotFound{} ->
                    {ok, general_error(404, <<"Invoice not found">>)};
                #payproc_InvalidUser{} ->
                    {ok, general_error(404, <<"Invoice not found">>)}
            end
    end;

%%

process_request(_OperationID, _Req, _Context) ->
    {error, noimpl}.

%%

encode_payer_params(#{
    <<"payerType" >> := <<"CustomerPayer">>,
    <<"customerID">> := ID
}) ->
    {customer, #payproc_CustomerPayerParams{customer_id = ID}};

encode_payer_params(#{
    <<"payerType"       >> := <<"PaymentResourcePayer">>,
    <<"paymentToolToken">> := Token,
    <<"paymentSession"  >> := EncodedSession,
    <<"contactInfo"     >> := ContactInfo
}) ->
    PaymentTool = capi_handler_encoder:encode_payment_tool_token(Token),
    {ClientInfo, PaymentSession} = capi_handler_utils:unwrap_payment_session(EncodedSession),
    {payment_resource, #payproc_PaymentResourcePayerParams{
        resource = #domain_DisposablePaymentResource{
            payment_tool = PaymentTool,
            payment_session_id = PaymentSession,
            client_info = capi_handler_encoder:encode_client_info(ClientInfo)
        },
        contact_info = capi_handler_encoder:encode_contact_info(ContactInfo)
    }};

encode_payer_params(#{
    <<"payerType"             >> := <<"RecurrentPayer">>,
    <<"recurrentParentPayment">> := RecurrentParent,
    <<"contactInfo"           >> := ContactInfo
}) ->
    #{
        <<"invoiceID">> := InvoiceID,
        <<"paymentID">> := PaymentID
    } = RecurrentParent,
    {recurrent, #payproc_RecurrentPayerParams{
        recurrent_parent = #domain_RecurrentParentPayment{
            invoice_id = InvoiceID,
            payment_id = PaymentID
        },
        contact_info = capi_handler_encoder:encode_contact_info(ContactInfo)
    }}.

encode_flow(#{<<"type">> := <<"PaymentFlowInstant">>}) ->
    {instant, #payproc_InvoicePaymentParamsFlowInstant{}};

encode_flow(#{<<"type">> := <<"PaymentFlowHold">>} = Entity) ->
    OnHoldExpiration = maps:get(<<"onHoldExpiration">>, Entity, <<"cancel">>),
    {hold, #payproc_InvoicePaymentParamsFlowHold{
        on_hold_expiration = binary_to_existing_atom(OnHoldExpiration, utf8)
    }}.

encode_optional_refund_cash(Params = #{<<"amount">> := _, <<"currency">> := _}, _, _, _) ->
    capi_handler_encoder:encode_cash(Params);
encode_optional_refund_cash(Params = #{<<"amount">> := _}, InvoiceID, PaymentID, Context) ->
    {ok, #payproc_InvoicePayment{
        payment = #domain_InvoicePayment{
            cost = #domain_Cash{currency = Currency}
        }
    }} = capi_handler_utils:get_payment_by_id(InvoiceID, PaymentID, Context),
    capi_handler_encoder:encode_cash(Params#{<<"currency">> => capi_handler_decoder_utils:decode_currency(Currency)});
encode_optional_refund_cash(_, _, _, _) ->
    undefined.

%%

decode_invoice_payment(InvoiceID, #payproc_InvoicePayment{payment = Payment}, Context) ->
    capi_handler_decoder_invoicing:decode_payment(InvoiceID, Payment, Context).

