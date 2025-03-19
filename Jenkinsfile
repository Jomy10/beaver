pipeline {
  agent { dockerfile true }
  stages {
    stage('Build') {
      steps {
        sh 'cargo build --release'
      }
    }
  }
}
