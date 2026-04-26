# Project 19: CICD with Github Actions
In this project, we will build step by step a CICD pipeline using Github Actions. This project builds and deploys an App(Rhena App) with DevSecOps best practices in three steps: 
 - Runs necessary code tests(maven, checkstyle, junit, jacoco and quality gates);
 - Builds a docker image and stores in ECR; and finaly
 - Deploys the latest image to ECS. RDS is used to store the app user creds and details about the app.

## Technologies 
- Spring MVC
- Spring Security
- Spring Data JPA
- Maven
- JSP
- MySQL

# Sonarcode analysis and quality gates
We need to start checking our workflow step by step, first we analyse our code for bugs with sonarqube
in the file CICD-with-GitActions/.github/workflows/main.yml replace all its contents with
```yml
name: CICD-with-GitActions
on: workflow_dispatch
  
jobs: 
  Testing:
    runs-on: ubuntu-latest
    steps:
      - name: Testing workflow
        uses: actions/checkout@v4

      - name: Maven test
        run: mvn test
      
      - name: Checkstyle
        run: mvn checkstyle:checkstyle
```
This portion of code does three things: downloads the sourcecode to github actions, runs maven test and runs mvn checkstyle. This is the first set of tests to be sure the code structure and styles are good and bug free. 
Now push this code and run it; 
```git
git add .
git commit "testing workflow"
git push
```
Now to GitHub -> Actions -> CICD-with-GitActions -> run workflow -> branch name: main, run workflow. Now you'll have been sure that the workflow works smoothly

### Sonarcloud setup
Create an account in [SonarCloud](https://www.sonarcloud.io) and link it to your github -> Create a new organization

- Create an organization manually
- Organization name: rhena (or give any random number after it if Rhena isn't valid) -> create organization
  ![Creating an organization](https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/creating%20organization.png)
- Analyse new project in the next window
  ```
  Display name: app
  Project key: rhena_app -> next
  Previous version = true -> create project  
  ```
- Choose analysis method: Github actions
- Copy the sonar token to a sticky note
  ![Sonar token]( https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/sonar%20token.png)
- Create a quality gate
  
    Under organizations select Rhena -> Quality gates -> Create -> Name: actionsQG
    ![Creating quality gate]( https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/create%20quality%20gate.png)
    Add conditions -> Where?: overall code -> Quality gate fails when: Bugs -> Operator: is greater than, Value 35
    Projects: rhena_app
  
- Secrets in Github
   In our project repo, under settings -> secrets and variables -> Actions -> new repository secret:
   add the following secrets(name: value):
    - SONAR_TOKEN : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx (input the token retrieved from above when creating project)
    - SONAR_URL : sonarcloud.io
    - SONAR_ORGANIZATION: rhena
    - SONAR_PROJECT_KEY: rhena_app

 - Test the sonar scanner and the quality gates, replace the content of the workflow(main.yml) with the following
```yml
  name: github Actions
  on: [push, workflow_dispatch]   
  jobs: 
    Testing:
      runs-on: ubuntu-latest
      steps:
        - name: Testing workflow
          uses: actions/checkout@v4
  
        - name: Maven test
          run: mvn test
        
        - name: Checkstyle
          run: mvn checkstyle:checkstyle
  
  # Setup java 11 to be default (sonar-scanner requirement as of 5.x)
        - name: Set Java 11
          uses: actions/setup-java@v3
          with:
            distribution: 'temurin' # See 'Supported distributions' for available options
            java-version: '11'
  
        # Setup sonar-scanner
        - name: Setup SonarQube
          uses: warchant/setup-sonar-scanner@v7
  
        # Run sonar-scanner
        - name: SonarQube Scan
          run: sonar-scanner
            -Dsonar.host.url=${{ secrets.SONAR_URL }}
            -Dsonar.login=${{ secrets.SONAR_TOKEN }}
            -Dsonar.organization=${{ secrets.SONAR_ORGANIZATION }}
            -Dsonar.projectKey=${{ secrets.SONAR_PROJECT_KEY }}
            -Dsonar.sources=src/
            -Dsonar.junit.reportsPath=target/surefire-reports/ 
            -Dsonar.jacoco.reportsPath=target/jacoco.exec 
            -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml
            -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/
  
                # Check the Quality Gate status.
        - name: SonarQube Quality Gate check
          id: sonarqube-quality-gate-check
          uses: sonarsource/sonarqube-quality-gate-action@master
        # Force to fail step after specific time.
          timeout-minutes: 5
          env:
            SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
            SONAR_HOST_URL: ${{ secrets.SONAR_URL }} #OPTIONAL 
```
Now push to code to Github which will automatically trigger the workflow. When the workflow ends, in sonarcloud, the report of the analysis will be available
![sonar scan report]( https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/sonar%20scan%20report.png )

## AWS IAM, ECR and RDS Setup
### AWS IAM
  Create an IAM user with the following policies
  - Cloudwatch full access
  - ECR full access
  - RDS full access
 Save the access keys in a sticky note

### ECR
  - Create a new private repository in ECR
  - Create repository -> name: rhenaapp -> create
  - Copy repository URI of the form xxxxxxxxx.dkr.ecr.us-east-2.amazonaws.com and store in sticky notes
    ![Created Repository in ECR](https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/created%20repository.png)
### RDS
  - Create a mysql database in RDS
    ```
     - Standard create = true
     - engine options: MySQL
     - engine version: 8.0.35
     - templates: freetier
     - db instance identifier: RhenaDB
     - credentials settings:
        -> master username: admin
        -> password: admin123
     - Connectivity:
        -> VPC security group: create new; -> name: rhena-sg
     - Additional configuration:
        - initial database name: accounts
     - Create database
    ```
   
   - After the database finishes the creating phase, we need to spin an EC2 instance to set up the database with initial data for our configuration
     
  - Start an ec2 instance
    ```
     - instance type: t2.micro
     - OS: ubuntu
     - security group: create new -> setup-sg
     - inboud rules: allow all traffic from my IP
    ```
     * Under security groups, edit the inbound rules of the RDS data base(sg name: rhena-sg) and allow incoming traffic from setup-sg
       
   - Back in our terminal, ssh into the ec2 isntance and run the following code
     ```
      sudo apt-get update
      sudo apt-get install mysql-server      
      git clone https://github.com/Ndzenyuy/Project-20_Github-actions.git
      cd Project-20_Github-actions/src/main/resources/
      mysql -u <user_name> -padmin123 accounts < db_backup.sql
     ```
     The above code will install mysql server, used to connect to mysql database, clone the project code and import the mysql dump found in db_backup.sql to the db server.
    At this point, the ec2 instance can be terminated.  The Database is ready to be used in our app.

## Docker build and publish to ECR
Back to GitHub secrets, add the following 
 - RDS_USER: admin
 - RDS_PASS: admin123
 - RDS_ENDPOINT: (url of your rds endpoint)
 - AWS_ACCESS_KEY_ID: < access key of the created IAM user >
 - AWS_SECRET_ACCESS_KEY: <secret access key of the created IAM user>
 - REGISTRY:  paste the URI of the copied ECR registry that was saved above

   Now update the content of main.yml with the following content
```
name: github Actions
on: [push, workflow_dispatch]
  
jobs: 
  Testing:
    runs-on: ubuntu-latest
    steps:
      - name: Testing workflow
        uses: actions/checkout@v4

      - name: Maven test
        run: mvn test
      
      - name: Checkstyle
        run: mvn checkstyle:checkstyle

# Setup java 11 to be default (sonar-scanner requirement as of 5.x)
      - name: Set Java 11
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin' # See 'Supported distributions' for available options
          java-version: '11'

      # Setup sonar-scanner
      - name: Setup SonarQube
        uses: warchant/setup-sonar-scanner@v7

      # Run sonar-scanner
      - name: SonarQube Scan
        run: sonar-scanner
          -Dsonar.host.url=${{ secrets.SONAR_URL }}
          -Dsonar.login=${{ secrets.SONAR_TOKEN }}
          -Dsonar.organization=${{ secrets.SONAR_ORGANIZATION }}
          -Dsonar.projectKey=${{ secrets.SONAR_PROJECT_KEY }}
          -Dsonar.sources=src/
          -Dsonar.junit.reportsPath=target/surefire-reports/ 
          -Dsonar.jacoco.reportsPath=target/jacoco.exec 
          -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml
          -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/

              # Check the Quality Gate status.
      - name: SonarQube Quality Gate check
        id: sonarqube-quality-gate-check
        uses: sonarsource/sonarqube-quality-gate-action@master
      # Force to fail step after specific time.
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_URL }} #OPTIONAL 

  BUILD_AND_PUBLISH:
    needs: Testing
    runs-on: ubuntu-latest
    steps:
      - name: Code checkout
        uses: actions/checkout@v4

      - name: Update application.properties file
        run: |
          sed -i "s/^jdbc.username.*$/jdbc.username\=${{ secrets.RDS_USER }}/" src/main/resources/application.properties
          sed -i "s/^jdbc.password.*$/jdbc.password\=${{ secrets.RDS_PASS }}/" src/main/resources/application.properties
          sed -i "s/db01/${{ secrets.RDS_ENDPOINT }}/" src/main/resources/application.properties

      - name: Build & Upload image to ECR
        uses: appleboy/docker-ecr-action@master
        with:
          access_key: ${{ secrets.AWS_ACCESS_KEY_ID }}
          secret_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          registry: ${{ secrets.REGISTRY }}
          repo: rhenaapp
          region: ${{ env.AWS_REGION }}
          tags: latest,${{ github.run_number }}
          daemon_off: false
          dockerfile: ./Dockerfile
          context: ./
```

The above code adds a new job to the workflow, builds and publishes the docker image to ECR.
 
## ECS Setup
Once the image is in ECR, we need to setup ECS to pick this image and deploy it. In AWS console, goto ECS
 - Create a cluster -> name: rhena-appl -> create. Wait for few minutes for the creation to complete
 - Create a task definition:
 ```
 - Name: Rhenaapp-tdef
 - CPU: 1vCPU, memery: 2GiB
 - Container details:
   name: rhenaapp
   container port: 8080
   image URI: <paste the image uri from ECR> : leave the rest as defaults
   
 ```
![]( https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/task%20definition%20creation%20success.png)
Now click on the task execution role which will lead you to IAM
![task definition creation success](https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/successful%20created%20service.png)

Now we need to add cloudwatch logs full access to the role
 -> Add permissions -> Attach policies -> cloudwatchLogsFullAccess -> add permissions
  

Back to clusters, create a service
```
Deployment configuration:
  - family: rhenaapp
  - service name: rhenaapp-svc
Deployment failue detection
  - Use the Amazon ECS deployment circuit breaker = false(uncheck)
Networking:
  - Security group: create new
    -> name: rhenaapp-sg
    -> inbound rules: HTTP from anywhere, 8080 from anywhere
  
Load balancing:
  - Application load balancer -> name: rhenaapplb
  - healthcheck grace period: 30s
  - listener: create new listener -> port 80
  - Create new target group:
     name: rhenaapp-tg
     healthcheck path: /login
```
![successful deployment ecs]( https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/successful%20create%20in%20ecs.png)

Now copy the DNS address of the ALB and paste it on the browser, we should have a login page of the app running in ECS
![access via dns]( https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/access%20via%20alb%20dns.png)

## Deploy

The last job will be to deploy the latest version of the app each time the workflow runs. Replace the main.yaml code with the following
```yml
name: github Actions
on: [push, workflow_dispatch]
env: 
  AWS_REGION: us-east-2
  ECR_REPOSITORY: rhenaapp
  ECS_SERVICE: rhenaapp-svc
  ECS_CLUSTER: rhena-appl
  ECS_TASK_DEFINITION: aws-files/taskdeffile.json
  CONTAINER_NAME: rhenaapp
  
jobs: 
  Testing:
    runs-on: ubuntu-latest
    steps:
      - name: Testing workflow
        uses: actions/checkout@v4

      - name: Maven test
        run: mvn test
      
      - name: Checkstyle
        run: mvn checkstyle:checkstyle

# Setup java 11 to be default (sonar-scanner requirement as of 5.x)
      - name: Set Java 11
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin' # See 'Supported distributions' for available options
          java-version: '11'

      # Setup sonar-scanner
      - name: Setup SonarQube
        uses: warchant/setup-sonar-scanner@v7

      # Run sonar-scanner
      - name: SonarQube Scan
        run: sonar-scanner
          -Dsonar.host.url=${{ secrets.SONAR_URL }}
          -Dsonar.login=${{ secrets.SONAR_TOKEN }}
          -Dsonar.organization=${{ secrets.SONAR_ORGANIZATION }}
          -Dsonar.projectKey=${{ secrets.SONAR_PROJECT_KEY }}
          -Dsonar.sources=src/
          -Dsonar.junit.reportsPath=target/surefire-reports/ 
          -Dsonar.jacoco.reportsPath=target/jacoco.exec 
          -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml
          -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/

              # Check the Quality Gate status.
      - name: SonarQube Quality Gate check
        id: sonarqube-quality-gate-check
        uses: sonarsource/sonarqube-quality-gate-action@master
      # Force to fail step after specific time.
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_URL }} #OPTIONAL 

  BUILD_AND_PUBLISH:
    needs: Testing
    runs-on: ubuntu-latest
    steps:
      - name: Code checkout
        uses: actions/checkout@v4

      - name: Update application.properties file
        run: |
          sed -i "s/^jdbc.username.*$/jdbc.username\=${{ secrets.RDS_USER }}/" src/main/resources/application.properties
          sed -i "s/^jdbc.password.*$/jdbc.password\=${{ secrets.RDS_PASS }}/" src/main/resources/application.properties
          sed -i "s/db01/${{ secrets.RDS_ENDPOINT }}/" src/main/resources/application.properties

      - name: Build & Upload image to ECR
        uses: appleboy/docker-ecr-action@master
        with:
          access_key: ${{ secrets.AWS_ACCESS_KEY_ID }}
          secret_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          registry: ${{ secrets.REGISTRY }}
          repo: rhenaapp
          region: ${{ env.AWS_REGION }}
          tags: latest,${{ github.run_number }}
          daemon_off: false
          dockerfile: ./Dockerfile
          context: ./

  Deploy:
    needs: BUILD_AND_PUBLISH
    runs-on: ubuntu-latest
    steps:
      - name: Code checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Fill in the new image ID in the Amazon ECS task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: ${{ env.ECS_TASK_DEFINITION }}
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ secrets.REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.run_number }}
      
      - name: Deploy Amazon ECS task definition
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
```
Copy the JSON content of the task definition and paste it in the file <project-folder>/aws-files/taskdeffile.json.
```json
{
    "taskDefinitionArn": "arn:aws:ecs:us-east-2:138380002982:task-definition/rhenaapp:8",
    "containerDefinitions": [
        {
            "name": "rhenaapp",
            "image": "138380002982.dkr.ecr.us-east-2.amazonaws.com/rhenaapp:22",
            "cpu": 0,
            "portMappings": [
                {
                    "name": "rhenaapp-8080-tcp",
                    "containerPort": 8080,
                    "hostPort": 8080,
                    "protocol": "tcp",
                    "appProtocol": "http"
                }
            ],
            "essential": true,
            "environment": [],
            "mountPoints": [],
            "volumesFrom": [],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-create-group": "true",
                    "awslogs-group": "/ecs/rhenaapp",
                    "awslogs-region": "us-east-2",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ],
    "family": "rhenaapp",
    "executionRoleArn": "arn:aws:iam::138380002982:role/ecsTaskExecutionRole",
    "networkMode": "awsvpc",
    "revision": 8,
    "volumes": [],
    "status": "ACTIVE",
    "requiresAttributes": [
        {
            "name": "com.amazonaws.ecs.capability.logging-driver.awslogs"
        },
        {
            "name": "ecs.capability.execution-role-awslogs"
        },
        {
            "name": "com.amazonaws.ecs.capability.ecr-auth"
        },
        {
            "name": "com.amazonaws.ecs.capability.docker-remote-api.1.19"
        },
        {
            "name": "ecs.capability.execution-role-ecr-pull"
        },
        {
            "name": "com.amazonaws.ecs.capability.docker-remote-api.1.18"
        },
        {
            "name": "ecs.capability.task-eni"
        },
        {
            "name": "com.amazonaws.ecs.capability.docker-remote-api.1.29"
        }
    ],
    "placementConstraints": [],
    "compatibilities": [
        "EC2",
        "FARGATE"
    ],
    "requiresCompatibilities": [
        "FARGATE"
    ],
    "cpu": "1024",
    "memory": "2048",
    "runtimePlatform": {
        "cpuArchitecture": "X86_64",
        "operatingSystemFamily": "LINUX"
    },
    "registeredAt": "2024-01-13T06:00:04.322Z",
    "registeredBy": "arn:aws:iam::138380002982:user/Jones",
    "tags": [
        {
            "key": "Name ",
            "value": "Rhenaapp-tdef"
        }
    ]
}
```

- Now edit the different variables to match those you gave in your setup. When pushed, the workflow should be triggered which, if successfull should have the following
![successful build of whole project]( https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/successful%20build%20whole%20project.png)

- Now edit the security group of the data base to accept inbound transfer of MySQL traffic from the security group of the ECS service.

Back to our web page, login with the following credentials
```
username: admin_vp
password: admin_vp
```
if the database is successfully connected, you should obtain a successful login into the web app.
![successful login](https://github.com/Ndzenyuy/Project-20_Github-actions/blob/main/images/login%20successful.png)

# Congratulations, you just deployed a webapp using GitHub actions
