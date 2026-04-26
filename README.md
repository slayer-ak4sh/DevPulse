# Mastering CI/CD — VProfile Java Web Application

A full-stack Java web application demonstrating a complete CI/CD pipeline using **GitHub Actions**, **SonarQube**, **Docker**, **Amazon ECR**, and **Amazon ECS (Fargate)**.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Java 8, Spring MVC, Spring Security, Hibernate |
| Database | MySQL 8 |
| Cache | Memcached |
| Message Broker | RabbitMQ |
| Search | Elasticsearch 5.6 |
| Build | Maven |
| Containerization | Docker (Tomcat 9 + JRE 11) |
| CI/CD | GitHub Actions |
| Code Quality | SonarQube, Checkstyle, JaCoCo |
| Registry | Amazon ECR |
| Deployment | Amazon ECS Fargate |

---

## Project Structure

```
├── .github/workflows/main.yml   # CI/CD pipeline
├── aws-files/taskdeffile.json   # ECS task definition
├── files/                       # Tomcat config files
├── src/
│   ├── main/
│   │   ├── java/                # Application source code
│   │   ├── resources/           # application.properties, SQL scripts
│   │   └── webapp/WEB-INF/      # Spring XML configs, JSP views
│   └── test/                    # Unit tests
├── Dockerfile                   # Multi-stage Docker build
└── pom.xml                      # Maven dependencies
```

---

## CI/CD Pipeline

The pipeline in `.github/workflows/main.yml` has three jobs:

### 1. Testing
- Checks out code with Java 11
- Runs `mvn test` and `mvn checkstyle:checkstyle`
- Switches to Java 17 for SonarQube scanner
- Runs SonarQube static analysis
- Enforces SonarQube Quality Gate

### 2. BUILD_AND_PUBLISH
- Injects RDS credentials into `application.properties` via `sed`
- Builds Docker image and pushes to Amazon ECR with `latest` and run-number tags

### 3. DEPLOY
- Renders a new ECS task definition with the updated image
- Deploys to ECS Fargate and waits for service stability

```
push → Testing → BUILD_AND_PUBLISH → DEPLOY
```

---

## Required GitHub Secrets

| Secret | Description |
|---|---|
| `SONAR_URL` | SonarQube server URL |
| `SONAR_TOKEN` | SonarQube authentication token |
| `SONAR_ORGANIZATION` | SonarQube organization key |
| `SONAR_PROJECT_KEY` | SonarQube project key |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `REGISTRY` | ECR registry URL (e.g. `<account>.dkr.ecr.us-east-1.amazonaws.com`) |
| `RDS_USER` | RDS MySQL username |
| `RDS_PASS` | RDS MySQL password |
| `RDS_ENDPOINT` | RDS MySQL endpoint hostname |

---

## Local Build

**Prerequisites:** Java 11+, Maven 3.6+

```bash
# Compile and package (skip tests)
mvn clean install -DskipTests

# Run tests
mvn test

# Run checkstyle
mvn checkstyle:checkstyle
```

The WAR file is produced at `target/vprofile-v2.war`.

---

## Docker Build

```bash
docker build -t vprofile-app .
docker run -p 8080:8080 vprofile-app
```

Access the app at `http://localhost:8080`

The Dockerfile uses a **multi-stage build**:
- Stage 1: `eclipse-temurin:11-jdk-jammy` — compiles and packages the WAR
- Stage 2: `tomcat:9-jre11-temurin` — serves the WAR

---

## AWS Infrastructure

| Resource | Value |
|---|---|
| Region | `us-east-1` |
| ECS Cluster | `github-actions` |
| ECS Service | `github-actions-svc` |
| ECR Repository | `github-actions` |
| Container Port | `8080` |
| Task CPU / Memory | `1024` / `2048` |
| Launch Type | Fargate |

---

## Application Configuration

`src/main/resources/application.properties` holds all service connection settings:

- **MySQL** — `jdbc.url`, `jdbc.username`, `jdbc.password` (injected at build time via CI)
- **Memcached** — `memcached.active.host`, `memcached.active.port`
- **RabbitMQ** — `rabbitmq.address`, `rabbitmq.port`, `rabbitmq.username`, `rabbitmq.password`
- **Elasticsearch** — `elasticsearch.host`, `elasticsearch.port`, `elasticsearch.cluster`

---

## Screenshots

| Step | Screenshot |
|---|---|
| Workflow completed | `images/completed workflow test.png` |
| SonarQube scan report | `images/sonar scan report.png` |
| ECS service created | `images/successful created service.png` |
| Access via ALB DNS | `images/access via alb dns.png` |

---

## Fixes Applied

- Replaced deprecated `openjdk:11` Docker base image with `eclipse-temurin:11-jdk-jammy`
- Replaced deprecated `mysql:mysql-connector-java` with `com.mysql:mysql-connector-j`
- Upgraded `commons-fileupload` from `1.3.1` to `1.5` (patches CVE-2023-24998)
- Fixed JDBC driver class from `com.mysql.jdbc.Driver` to `com.mysql.cj.jdbc.Driver`
- Added `actions/setup-java@v4` before Maven test steps in the workflow
- Upgraded `configure-aws-credentials` from `v1` to `v2`
- Added `.dockerignore` to reduce Docker build context size
