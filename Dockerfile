FROM eclipse-temurin:11-jdk-jammy AS BUILD_IMAGE
WORKDIR /vprofile-project
COPY pom.xml .
RUN apt-get update && apt-get install -y maven --no-install-recommends && rm -rf /var/lib/apt/lists/*
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn install -DskipTests

FROM tomcat:9-jre11-temurin
LABEL "Project"="Vprofile"
LABEL "Author"="Imran"
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=BUILD_IMAGE /vprofile-project/target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
CMD ["catalina.sh", "run"]
