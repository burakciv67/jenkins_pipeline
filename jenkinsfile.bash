/*This pipeline developed by Burak CIV*/

pipeline {
    agent any

   parameters {
    choice(name: 'ServiceChoice', choices: ['imagename1','imagename12'], description: 'Select the service')
    }
  
    environment {
	    REGISTRY_TEST = "xxxxxx"  // internal image repo url
        IMAGE = "${params.ServiceChoice}"
        OPENSHIFT_SERVER = "xxxxxx"  // internal image repo url
		OPENSHIFT_CREDENTIALS = "ocp-wallettest"  // jenkins credentials to login ocp
        OPENSHIFT_DEPLOY_NAME = "${params.ServiceChoice}"
   		VERSION = "${params.choiceVersion}"
        DOCKER_URL = "registry.fraud.com/" //external fraud repo url
    }

    stages {
      
        stage('Image Pull External Repo') {
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_URL}", 'ihsdockeruser') {
                      docker.image("${IMAGE}:${VERSION}").pull()                      
                    }
                }
            }
			
			
        }        
        stage('Push Internal Repo') {   
            steps {
                script {
                    docker.withRegistry("${REGISTRY_TEST}", 'cashflow_nexus') {
					docker.image("${DOCKER_URL}${IMAGE}:${VERSION}").push()
                    }
                }
            }
        }
        
       stage('Image Scanning with Smart Check') {   
            steps {
              echo "Smart Check jobunda kullanılan serviceName: ${params.ServiceChoice}"
              echo "Smart Check jobunda kullanılan imageName: ${DOCKER_URL}${IMAGE}:${VERSION}"
              build job: "smartcheck",
              parameters: [[$class: 'StringParameterValue', name: 'imageName', value: "${DOCKER_URL}${IMAGE}:${VERSION}"]],
              propagate: 'true',
              wait: 'true'

            }
        }
		
		
		stage('Ocp Restart ') {   
    steps {  
        sh 'echo deploy'  
        withCredentials([usernamePassword(credentialsId: OPENSHIFT_CREDENTIALS, passwordVariable: 'PASSWORD', usernameVariable: 'USER_NAME')]) {  
            script {  
                def OPENSHIFT_TOKEN = sh(returnStdout: true, script: """  
                                                oc login ${OPENSHIFT_SERVER}  \\
                                                -u $USER_NAME -p $PASSWORD --insecure-skip-tls-verify=true &> /dev/null &&\\
                                                oc whoami -t  
                                              """)  

                openshift.withCluster("insecure://${OPENSHIFT_SERVER}", "${OPENSHIFT_TOKEN}") {  
                    openshift.withProject("fraud") {  
                        def ocpDeployName   = OPENSHIFT_DEPLOY_NAME
                    						 sh "echo ocpDeployName : $ocpDeployName"  
                        if (OPENSHIFT_DEPLOY_NAME.startsWith("aireflex/")) {  
                            ocpDeployName = OPENSHIFT_DEPLOY_NAME.substring(9)  
                        } else if (OPENSHIFT_DEPLOY_NAME.startsWith("fcase/")) {  
                            ocpDeployName = OPENSHIFT_DEPLOY_NAME.substring(6)  
                        } else {  
                            error "OPENSHIFT_DEPLOY_NAME is not valid"  
                        }  

                        sh "oc project fraud"  
                        sh "oc project -q"  
                        def container_name = sh(script: "oc get deployment ${ocpDeployName} -o=jsonpath='{.spec.template.spec.containers[0].name}'", returnStdout: true).trim()  
                        sh "echo container_name : $container_name"  
                        def nexus = REGISTRY_TEST.substring(7)  
                        sh "oc set image deployment/${ocpDeployName} ${container_name}=${nexus}/${DOCKER_URL}${OPENSHIFT_DEPLOY_NAME}:${env.VERSION}"  
                    }  
                }  
            }  
        }  
      }  
    } 




	
  }
}