-module(capi_feature_schemas).

-type schema() :: capi_idemp_features:schema().

-include("capi_feature_schemas.hrl").

-define(id, 1).
-define(invoice_id, 2).
-define(make_recurrent, 3).
-define(flow, 4).
-define(hold_exp, 5).
-define(payer, 6).
-define(payment_tool, 7).
-define(token, 8).
-define(bank_card, 9).
-define(exp_date, 10).
-define(terminal, 11).
-define(terminal_type, 12).
-define(wallet, 13).
-define(provider, 14).
-define(crypto, 15).
-define(currency, 16).
-define(mobile_commerce, 17).
-define(operator, 18).
-define(phone, 19).
-define(customer, 20).
-define(recurrent, 21).
-define(invoice, 22).
-define(payment, 23).
-define(shop_id, 24).
-define(amount, 25).
-define(product, 26).
-define(due_date, 27).
-define(cart, 28).
-define(quantity, 29).
-define(price, 30).
-define(tax, 31).
-define(rate, 32).
-define(bank_account, 33).
-define(account, 34).
-define(bank_bik, 35).
-define(payment_resource, 36).
-define(payment_session, 37).
-define(lifetime, 38).
-define(details, 39).
-define(days, 40).
-define(months, 41).
-define(years, 42).
-define(single_line, 43).
-define(multiline, 44).
-define(range, 45).
-define(fixed, 46).
-define(lower_bound, 47).
-define(upper_bound, 48).

-export([payment/0]).
-export([invoice/0]).
-export([invoice_template/0]).
-export([refund/0]).
-export([customer_binding/0]).

-spec payment() -> schema().
payment() ->
    #{
        ?invoice_id => [<<"invoiceID">>],
        ?make_recurrent => [<<"makeRecurrent">>],
        ?flow => [
            <<"flow">>,
            #{
                ?discriminator => [<<"type">>],
                ?hold_exp => [<<"onHoldExpiration">>]
            }
        ],
        ?payer => [
            <<"payer">>,
            #{
                ?discriminator => [<<"payerType">>],
                ?payment_tool => [<<"paymentTool">>, payment_tool_schema()],
                ?customer => [<<"customerID">>],
                ?recurrent => [
                    <<"recurrentParentPayment">>,
                    #{
                        ?invoice => [<<"invoiceID">>],
                        ?payment => [<<"paymentID">>]
                    }
                ]
            }
        ]
    }.

-spec invoice() -> schema().
invoice() ->
    #{
        ?shop_id => [<<"shopID">>],
        ?amount => [<<"amount">>],
        ?currency => [<<"currency">>],
        ?product => [<<"product">>],
        ?due_date => [<<"dueDate">>],
        ?cart => [<<"cart">>, {set, cart_line_schema()}],
        ?bank_account => [<<"bankAccount">>, bank_account_schema()]
    }.

-spec invoice_template() -> schema().
invoice_template() ->
    #{
        ?shop_id => [<<"shopID">>],
        ?lifetime => [<<"lifetime">>, lifetime_schema()],
        ?details => [<<"details">>, invoice_template_details_schema()]
    }.

-spec invoice_template_details_schema() -> schema().
invoice_template_details_schema() ->
    #{
        ?discriminator => [<<"templateType">>],
        ?single_line => #{
            ?product => [<<"product">>],
            ?price => [<<"price">>, invoice_template_line_cost()],
            ?tax => [<<"taxMode">>, tax_mode_schema()]
        },
        ?multiline => #{
            ?currency => [<<"currency">>],
            ?cart => [<<"cart">>, {set, cart_line_schema()}]
        }
    }.

-spec refund() -> schema().
refund() ->
    #{
        ?amount => [<<"amount">>],
        ?currency => [<<"currency">>],
        ?cart => [<<"cart">>, {set, cart_line_schema()}]
    }.

-spec customer_binding() -> schema().
customer_binding() ->
    #{
        ?payment_resource => [
            <<"paymentResource">>,
            #{
                ?payment_session => [<<"paymentSession">>],
                ?payment_tool => [<<"paymentTool">>, payment_tool_schema()]
            }
        ]
    }.

-spec payment_tool_schema() -> schema().
payment_tool_schema() ->
    #{
        ?discriminator => [<<"type">>],
        ?bank_card => #{
            ?token => [<<"token">>],
            ?exp_date => [<<"exp_date">>]
        },
        ?terminal => #{
            ?discriminator => [<<"terminal_type">>]
        },
        ?wallet => #{
            ?provider => [<<"provider">>],
            ?id => [<<"id">>],
            ?token => [<<"token">>]
        },
        ?crypto => #{
            ?currency => [<<"currency">>]
        },
        ?mobile_commerce => #{
            ?operator => [<<"operator">>],
            ?phone => [<<"phone">>]
        }
    }.

-spec cart_line_schema() -> schema().
cart_line_schema() ->
    #{
        ?product => [<<"product">>],
        ?quantity => [<<"quantity">>],
        ?price => [<<"price">>],
        ?tax => [<<"taxMode">>, tax_mode_schema()]
    }.

-spec tax_mode_schema() -> schema().
tax_mode_schema() ->
    #{
        ?discriminator => [<<"type">>],
        ?rate => [<<"rate">>]
    }.

-spec bank_account_schema() -> schema().
bank_account_schema() ->
    #{
        ?discriminator => [<<"accountType">>],
        ?account => [<<"account">>],
        ?bank_bik => [<<"bankBik">>]
    }.

invoice_template_line_cost() ->
    #{
        ?discriminator => [<<"costType">>],
        ?range => #{
            ?currency => [<<"currency">>],
            ?range => [<<"range">>, cost_amount_range()]
        },
        ?fixed => #{
            ?currency => [<<"currency">>],
            ?amount => [<<"amount">>]
        }
        %% Unlim has no params and is fully contained in discriminator
    }.

-spec cost_amount_range() -> schema().
cost_amount_range() ->
    #{
        ?upper_bound => [<<"upperBound">>],
        ?lower_bound => [<<"lowerBound">>]
    }.

-spec lifetime_schema() -> schema().
lifetime_schema() ->
    #{
        ?days => [<<"days">>],
        ?months => [<<"months">>],
        ?years => [<<"years">>]
    }.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-include_lib("capi_dummy_data.hrl").

deep_merge(M1, M2) ->
    maps:fold(
        fun
            (K, V, MAcc) when is_map(V) ->
                Value = deep_merge(maps:get(K, MAcc, #{}), V),
                MAcc#{K => Value};
            (K, V, MAcc) ->
                MAcc#{K => V}
        end,
        M1,
        M2
    ).

hash(Term) ->
    capi_idemp_features:hash(Term).
read(Schema, Request) ->
    capi_idemp_features:read(Schema, Request).
compare(Features1, Features2) ->
    capi_idemp_features:compare(Features1, Features2).
list_diff_fields(Schema, Diff) ->
    capi_idemp_features:list_diff_fields(Schema, Diff).

-spec test() -> _.

-spec read_payment_features_test() -> _.

read_payment_features_test() ->
    PayerType = <<"PaymentResourcePayer">>,
    ToolType = <<"bank_card">>,
    Token = <<"cds token">>,
    CardHolder = <<"0x42">>,
    Category = <<"BUSINESS">>,
    ExpDate = {exp_date, 02, 2022},
    Flow = <<"PaymentFlowHold">>,
    Request = #{
        <<"flow">> => #{
            <<"type">> => Flow
        },
        <<"payer">> => #{
            <<"payerType">> => PayerType,
            <<"paymentTool">> => #{
                <<"type">> => ToolType,
                <<"token">> => Token,
                <<"exp_date">> => ExpDate,
                <<"cardholder_name">> => CardHolder,
                <<"category">> => Category
            }
        }
    },
    Payer = #{
        ?invoice_id => undefined,
        ?make_recurrent => undefined,
        ?flow => #{
            ?discriminator => hash(Flow),
            ?hold_exp => undefined
        },
        ?payer => #{
            ?discriminator => hash(PayerType),
            ?customer => undefined,
            ?recurrent => undefined,
            ?payment_tool => #{
                ?discriminator => hash(ToolType),
                ?bank_card => #{
                    ?exp_date => hash(ExpDate),
                    ?token => hash(Token)
                },
                ?crypto => #{?currency => undefined},
                ?mobile_commerce => #{
                    ?operator => undefined,
                    ?phone => undefined
                },
                ?terminal => #{?discriminator => undefined},
                ?wallet => #{
                    ?id => undefined,
                    ?provider => undefined,
                    ?token => hash(Token)
                }
            }
        }
    },
    Features = capi_idemp_features:read(payment(), Request),
    ?assertEqual(Payer, Features).

-spec compare_payment_bank_card_test() -> _.
compare_payment_bank_card_test() ->
    Token2 = <<"cds token 2">>,
    CardHolder2 = <<"Cake">>,

    PaymentTool1 = bank_card(),
    PaymentTool2 = PaymentTool1#{
        <<"token">> => Token2,
        <<"cardholder_name">> => CardHolder2
    },
    Request1 = payment_params(PaymentTool1),
    Request2 = payment_params(PaymentTool2),

    Schema = payment(),
    F1 = capi_idemp_features:read(Schema, Request1),
    F2 = capi_idemp_features:read(Schema, Request2),
    ?assertEqual(true, capi_idemp_features:compare(F1, F1)),
    {false, Diff} = capi_idemp_features:compare(F1, F2),
    ?assertEqual(
        [
            <<"payer.paymentTool.token">>
        ],
        list_diff_fields(Schema, Diff)
    ).

-spec compare_different_payment_tool_test() -> _.
compare_different_payment_tool_test() ->
    ToolType2 = <<"wallet">>,
    Token2 = <<"wallet token">>,
    PaymentTool1 = bank_card(),
    PaymentTool2 = #{
        <<"type">> => ToolType2,
        <<"token">> => Token2
    },
    Request1 = payment_params(PaymentTool1),
    Request2 = payment_params(PaymentTool2),
    Schema = payment(),
    F1 = capi_idemp_features:read(Schema, Request1),
    F2 = capi_idemp_features:read(Schema, Request2),
    ?assertEqual(true, capi_idemp_features:compare(F1, F1)),
    {false, Diff} = capi_idemp_features:compare(F1, F2),
    ?assertEqual([<<"payer.paymentTool">>], capi_idemp_features:list_diff_fields(Schema, Diff)).

-spec feature_multi_accessor_test() -> _.
feature_multi_accessor_test() ->
    Request1 = #{
        <<"payer">> => #{
            <<"payerType">> => <<"PaymentResourcePayer">>,
            <<"paymentTool">> => #{
                <<"wrapper">> => bank_card()
            }
        }
    },
    Request2 = deep_merge(Request1, #{
        <<"payer">> => #{
            <<"paymentTool">> => #{
                <<"wrapper">> => #{
                    <<"token">> => <<"cds token 2">>,
                    <<"cardholder_name">> => <<"Cake">>
                }
            }
        }
    }),
    Schema = #{
        <<"payer">> => [
            <<"payer">>,
            #{
                <<"type">> => [<<"payerType">>],
                <<"tool">> => [
                    <<"paymentTool">>,
                    <<"wrapper">>,
                    #{
                        <<"$type">> => [<<"type">>],
                        <<"bank_card">> => #{
                            <<"token">> => [<<"token">>],
                            <<"exp_date">> => [<<"exp_date">>]
                        }
                    }
                ]
            }
        ]
    },
    F1 = capi_idemp_features:read(Schema, Request1),
    F2 = capi_idemp_features:read(Schema, Request2),
    ?assertEqual(true, capi_idemp_features:compare(F1, F1)),
    {false, Diff} = capi_idemp_features:compare(F1, F2),
    ?assertEqual(
        [
            <<"payer.paymentTool.wrapper.token">>
        ],
        capi_idemp_features:list_diff_fields(Schema, Diff)
    ).

-spec read_payment_customer_features_value_test() -> _.
read_payment_customer_features_value_test() ->
    PayerType = <<"CustomerPayer">>,
    CustomerID = <<"some customer id">>,
    Request = #{
        <<"payer">> => #{
            <<"payerType">> => PayerType,
            <<"customerID">> => CustomerID
        }
    },
    Features = capi_idemp_features:read(payment(), Request),
    ?assertEqual(
        #{
            ?invoice_id => undefined,
            ?make_recurrent => undefined,
            ?flow => undefined,
            ?payer => #{
                ?discriminator => hash(PayerType),
                ?customer => hash(CustomerID),
                ?recurrent => undefined,
                ?payment_tool => undefined
            }
        },
        Features
    ).

-spec read_invoice_features_test() -> _.
read_invoice_features_test() ->
    ShopID = <<"shopus">>,
    Cur = <<"XXX">>,
    Prod1 = <<"yellow duck">>,
    Prod2 = <<"blue duck">>,
    DueDate = <<"2019-08-24T14:15:22Z">>,
    Price1 = 10000,
    Price2 = 20000,
    Quantity = 1,
    Product = #{
        ?product => hash(Prod1),
        ?quantity => hash(Quantity),
        ?price => hash(Price1),
        ?tax => undefined
    },
    Product2 = Product#{
        ?product => hash(Prod2),
        ?price => hash(Price2)
    },
    BankAccount = #{
        ?discriminator => hash(<<"InvoiceRussianBankAccount">>),
        ?account => hash(<<"12345678901234567890">>),
        ?bank_bik => hash(<<"123456789">>)
    },
    Invoice = #{
        ?amount => undefined,
        ?currency => hash(Cur),
        ?shop_id => hash(ShopID),
        ?product => undefined,
        ?due_date => hash(DueDate),
        ?bank_account => BankAccount,
        ?cart => [
            [1, Product],
            [0, Product2]
        ]
    },
    Request = #{
        <<"externalID">> => <<"externalID">>,
        <<"dueDate">> => DueDate,
        <<"shopID">> => ShopID,
        <<"currency">> => Cur,
        <<"description">> => <<"Wild birds.">>,
        <<"bankAccount">> => #{
            <<"accountType">> => <<"InvoiceRussianBankAccount">>,
            <<"account">> => <<"12345678901234567890">>,
            <<"bankBik">> => <<"123456789">>
        },
        <<"cart">> => [
            #{<<"product">> => Prod2, <<"quantity">> => 1, <<"price">> => Price2},
            #{<<"product">> => Prod1, <<"quantity">> => 1, <<"price">> => Price1, <<"not feature">> => <<"hmm">>}
        ],
        <<"metadata">> => #{}
    },

    Features = capi_idemp_features:read(invoice(), Request),
    ?assertEqual(Invoice, Features).

-spec compare_invoices_features_test() -> _.
compare_invoices_features_test() ->
    ShopID = <<"shopus">>,
    Cur = <<"RUB">>,
    Prod1 = <<"yellow duck">>,
    Prod2 = <<"blue duck">>,
    Price1 = 10000,
    Price2 = 20000,
    Product = #{
        <<"product">> => Prod1,
        <<"quantity">> => 1,
        <<"price">> => Price1,
        <<"taxMode">> => #{
            <<"type">> => <<"InvoiceLineTaxVAT">>,
            <<"rate">> => <<"10%">>
        }
    },
    Request1 = #{
        <<"shopID">> => ShopID,
        <<"currency">> => Cur,
        <<"cart">> => [Product]
    },
    Request2 = deep_merge(Request1, #{
        <<"cart">> => [#{<<"product">> => Prod2, <<"price">> => Price2}]
    }),
    Request3 = deep_merge(Request1, #{
        <<"cart">> => [#{<<"product">> => Prod2, <<"price">> => Price2, <<"quantity">> => undefined}]
    }),
    Schema = invoice(),
    Invoice1 = capi_idemp_features:read(Schema, Request1),
    InvoiceChg1 = capi_idemp_features:read(Schema, Request1#{
        <<"cart">> => [
            Product#{
                <<"price">> => Price2,
                <<"taxMode">> => #{
                    <<"rate">> => <<"18%">>
                }
            }
        ]
    }),
    Invoice2 = capi_idemp_features:read(Schema, Request2),
    InvoiceWithFullCart = capi_idemp_features:read(Schema, Request3),
    ?assertEqual(
        {false, #{
            ?cart => #{
                0 => #{
                    ?price => ?difference,
                    ?product => ?difference,
                    ?quantity => ?difference,
                    ?tax => ?difference
                }
            }
        }},
        capi_idemp_features:compare(Invoice2, Invoice1)
    ),
    ?assert(capi_idemp_features:compare(Invoice1, Invoice1)),
    %% Feature was deleted
    ?assert(capi_idemp_features:compare(InvoiceWithFullCart, Invoice2)),
    %% Feature was add
    ?assert(capi_idemp_features:compare(Invoice2, InvoiceWithFullCart)),
    %% When second request didn't contain feature, this situation detected as conflict.
    ?assertEqual(
        {false, #{?cart => ?difference}},
        capi_idemp_features:compare(Invoice1#{?cart => undefined}, Invoice1)
    ),

    {false, Diff} = capi_idemp_features:compare(Invoice1, InvoiceChg1),
    ?assertEqual(
        [<<"cart.0.price">>, <<"cart.0.taxMode.rate">>],
        capi_idemp_features:list_diff_fields(Schema, Diff)
    ),
    ?assert(capi_idemp_features:compare(Invoice1, Invoice1#{?cart => undefined})).

-spec read_customer_binding_features_test() -> _.
read_customer_binding_features_test() ->
    Session = ?TEST_PAYMENT_SESSION(<<"Session">>),
    Tool = ?TEST_PAYMENT_TOOL(visa, <<"TOKEN">>),
    Request = payment_resource(Session, Tool),
    Features = #{
        ?payment_resource => #{
            ?payment_session => hash(Session),
            ?payment_tool => #{
                ?discriminator => hash(<<"bank_card">>),
                ?bank_card => #{
                    ?token => hash(<<"TOKEN">>),
                    ?exp_date => hash(<<"12/2012">>)
                },

                ?terminal => #{
                    ?discriminator => undefined
                },
                ?wallet => #{
                    ?provider => undefined,
                    ?id => undefined,
                    ?token => hash(<<"TOKEN">>)
                },
                ?crypto => #{
                    ?currency => undefined
                },
                ?mobile_commerce => #{
                    ?operator => undefined,
                    ?phone => undefined
                }
            }
        }
    },

    ?assertEqual(
        Features,
        capi_idemp_features:read(customer_binding(), Request)
    ).

-spec compare_customer_binding_features_test() -> _.
compare_customer_binding_features_test() ->
    Session1 = ?TEST_PAYMENT_SESSION(<<"Session1">>),
    Tool1 = ?TEST_PAYMENT_TOOL(visa),
    Request1 = payment_resource(Session1, Tool1),

    Session2 = ?TEST_PAYMENT_SESSION(<<"Session2">>),
    Tool2 = ?TEST_PAYMENT_TOOL(mastercard)#{<<"exp_date">> => <<"01/2020">>},
    Request2 = payment_resource(Session2, Tool2),

    Schema = customer_binding(),

    F1 = read(Schema, Request1),
    F2 = read(Schema, Request2),

    ?assertEqual(true, compare(F1, F1)),
    {false, Diff} = compare(F1, F2),
    ?assertEqual(
        [
            <<"paymentResource.paymentTool.exp_date">>,
            <<"paymentResource.paymentSession">>
        ],
        list_diff_fields(Schema, Diff)
    ).

payment_resource(Session, Tool) ->
    #{
        <<"paymentResource">> => #{
            <<"paymentSession">> => Session,
            <<"paymentTool">> => Tool
        }
    }.

payment_params(ExternalID, MakeRecurrent) ->
    genlib_map:compact(#{
        <<"externalID">> => ExternalID,
        <<"flow">> => #{<<"type">> => <<"PaymentFlowInstant">>},
        <<"makeRecurrent">> => MakeRecurrent,
        <<"metadata">> => #{<<"bla">> => <<"*">>},
        <<"processingDeadline">> => <<"5m">>
    }).

payment_params(ExternalID, Jwe, ContactInfo, MakeRecurrent) ->
    Params = payment_params(ExternalID, MakeRecurrent),
    genlib_map:compact(Params#{
        <<"payer">> => #{
            <<"payerType">> => <<"PaymentResourcePayer">>,
            <<"paymentSession">> => <<"payment.session">>,
            <<"paymentToolToken">> => Jwe,
            <<"contactInfo">> => ContactInfo
        }
    }).

payment_params(PaymentTool) ->
    Params = payment_params(<<"EID">>, <<"Jwe">>, #{}, false),
    PaymentParams = deep_merge(Params, #{<<"payer">> => #{<<"paymentTool">> => PaymentTool}}),
    PaymentParams.

bank_card() ->
    #{
        <<"type">> => <<"bank_card">>,
        <<"token">> => <<"cds token">>,
        <<"payment_system">> => <<"visa">>,
        <<"bin">> => <<"411111">>,
        <<"last_digits">> => <<"1111">>,
        <<"exp_date">> => <<"2019-08-24T14:15:22Z">>,
        <<"cardholder_name">> => <<"Degus Degusovich">>,
        <<"is_cvv_empty">> => false
    }.

-endif.
