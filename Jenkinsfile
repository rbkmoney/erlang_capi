#!groovy

def finalHook = {
  runStage('store CT logs') {
    archive '_build/test/logs/'
  }
}

build('capi', 'docker-host', finalHook) {
  checkoutRepo()
  loadBuildUtils()

  def pipeDefault
  runStage('load pipeline') {
    env.JENKINS_LIB = "build_utils/jenkins_lib"
    pipeDefault = load("${env.JENKINS_LIB}/pipeDefault.groovy")
  }

  pipeDefault() {
    runStage('compile') {
      withGithubPrivkey {
        sh 'make wc_compile'
      }
    }
    // TODO fix issues
    // runStage('lint') {
    //   sh 'make wc_lint'
    // }
    runStage('xref') {
      sh 'make wc_xref'
    }
    // TODO fix issues
    // runStage('dialyze') {
    //   sh 'make wc_dialyze'
    // }
    runStage('test') {
      sh "make wdeps_test"
    }
    runStage('make release') {
      withGithubPrivkey {
        sh "make wc_release"
      }
    }
    runStage('build image') {
      sh "make build_image"
    }
    if (env.BRANCH_NAME == 'master') {
      runStage('push image') {
        sh "make push_image"
      }
    }
  }
}
