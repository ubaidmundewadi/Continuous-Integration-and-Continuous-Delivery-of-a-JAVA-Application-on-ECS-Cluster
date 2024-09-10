# Continuous-Integration-and-Continuous-Delivery-of-a-JAVA-Application-on-ECS-Cluster

## Project Overview

This project demonstrates the implementation of a Continuous Integration (CI) and Continuous Delivery (CD) pipeline for a Java-based web application using **Jenkins**, **SonarQube**, **Docker**, **Amazon ECR**, and **Amazon ECS**. The pipeline ensures automated testing, code analysis, artifact management, and deployment of the application into staging and production environments hosted on ECS clusters.

## Architecture Diagram

![Continous Delivery of Java Web Application](https://github.com/user-attachments/assets/7d100eab-4955-48c5-acb9-086e159503cf)

## Workflow Summary

1. **Source Code Management**:  
   Developers push their code to **GitHub**. The CI/CD pipeline is triggered by a push or pull request to specific branches.

2. **Separate Pipelines for Staging and Production**:  
   - **Staging Pipeline**: Code pushed to the staging branch triggers a build process, followed by deployment to the staging ECS cluster.
   - **Production Pipeline**: Once the code is tested and merged into the production branch, the production pipeline is triggered to deploy the application to the production ECS cluster.

3. **Fetch Code**:  
   Jenkins fetches the code from the respective branch using the **Git** plugin.

4. **Unit Tests and Checkstyle**:  
   The pipeline uses **Maven** to run unit tests and check the code against established coding standards using **Checkstyle**.

5. **Static Code Analysis with SonarQube**:  
   Jenkins integrates with **SonarQube** to perform static code analysis, identifying potential bugs, code smells, and security vulnerabilities. A quality gate is defined, and the build is halted if the code does not meet the quality standards.

6. **Docker Build**:  
   Once the code passes all checks and tests, a Docker image is built from the project using the **Docker** plugin in Jenkins. This image contains the necessary runtime environment and application code.

7. **Artifact Management**:  
   The Docker image is pushed to **Amazon Elastic Container Registry (ECR)** as the artifact repository.

8. **Deployment to ECS Clusters**:  
   - **Staging Cluster**: The image is deployed to the ECS staging environment for further manual or automated testing.
   - **Production Cluster**: After merging the code into the `production` branch, Jenkins triggers the production pipeline to deploy the application to the production ECS cluster.

## Tools and Technologies

- **Jenkins**: Automated CI/CD server
- **SonarQube**: Static code analysis tool
- **Maven**: Build automation and dependency management tool for Java
- **Docker**: Containerization of the application
- **Amazon ECR**: Docker image registry
- **Amazon ECS**: Managed container orchestration service
- **GitHub**: Source code repository
- **Checkstyle**: Code quality checks

## Jenkins Plugins Used

1. **GitHub Integration**: For pulling code from GitHub and handling webhooks.
2. **Maven Integration**: For building and testing Java projects using Maven.
3. **SonarQube Scanner**: For performing static code analysis.
4. **Nexus Artifact Uploader**: To store the build artifacts in Nexus repository (optional, not used in the current flow but can be integrated).
5. **CloudBees Docker Build and Publish**: For building Docker images and pushing them to ECR.
6. **AWS ECR**: For interacting with Amazon ECR to push Docker images.
7. **Docker Pipeline**: For managing Docker images and containers within a Jenkins Pipeline.
8. **Pipeline: AWS Steps**: For executing AWS CLI commands within the Jenkins pipeline.
9. **Pipeline Stage View**: For visualizing pipeline execution stages.
10. **Build Timestamp**: To display timestamps for builds in Jenkins logs.

## Setup Instructions

1. **Jenkins Configuration**:
   - Install and configure the plugins listed above.
   - Create separate Jenkins pipelines for staging and production environments.

2. **SonarQube Setup**:
   - Set up a SonarQube server and configure a quality gate.
   - Integrate Jenkins with SonarQube using the SonarQube Scanner plugin.

3. **Docker and ECR**:
   - Install Docker on the Jenkins agent.
   - Set up Amazon ECR and configure credentials for Jenkins to push Docker images to ECR.

4. **ECS Clusters**:
   - Create two ECS clusters: one for staging and one for production.
   - Set up the ECS task definition, services, and auto-scaling policies.

5. **Deployment**:
   - Jenkins should deploy the Docker image to the staging ECS cluster for testing.
   - Upon successful testing, merge the code into the `production` branch, which triggers the production pipeline for deployment to the production ECS cluster.

## Pipeline Flow

1. **Code Push**: Developer pushes code to GitHub.
2. **CI Build (Staging)**: Jenkins pulls the code from the staging branch, runs unit tests, and performs code quality checks using SonarQube.
3. **Docker Build**: If all checks pass, a Docker image is built and pushed to Amazon ECR.
4. **Staging Deployment**: The Docker image is deployed to the staging ECS cluster.
5. **Production Deployment**: After testing and merging the code into the production branch, Jenkins triggers the production pipeline to deploy the application to the production ECS cluster.

## Jenkins
![Screenshot 2024-09-10 001957](https://github.com/user-attachments/assets/133708a0-7a4f-4ddd-a58a-7e7a50f0bd9e)

## SonarQube
![Screenshot 2024-09-10 001611](https://github.com/user-attachments/assets/15511c40-0f08-476a-bae4-88ef1cd7fa93)

## Application
![Screenshot 2024-09-08 215820](https://github.com/user-attachments/assets/f605243d-6f93-4fa4-bca8-a868c1177157)
