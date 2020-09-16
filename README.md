## GitLab Setup on an ec2 instance

Many enterprise customers wants to use GitLab as single tool for maintaining their code repositories, CI/CD pipeline and storing the docker container images in GitLab container registry.
In this article, we will see how to quickly setup GitLab repository, GitLab Runner and GitLab container registry. This will be really useful if the customer is using GitLab in their environment for CI/CD and storing their container registries.
For detailed manual step by step executions, please check it here: https://github.com/srikanth311/Enabling-Container-Registry-In-Gitlab

Here I have created a shell script which automates the process of setting up GitLab and other components and it will be invoked via cloudformation scripts.

### Step 1: Use the step1-vpc.yaml cloudformation script to setup the VPC and subnets.
##### You can skip this setup, if you want to deploy in an existing VPC.

### Step 2: Use "step2-create-ec2-instance.yaml" script to setup the EC2 instance and execute the GitLab setup script.

### Step 3: Login to Gitlab UI
##### Once the Step2 execution is completed, login to the AWS EC2 console and find out the EC2 instance that was created with the name "AWSBlogBeanstalk-EC2Instance".
##### Get the public IP address of the instance and make sure, security group that is attached to the instance is allowing port 80. By default it will allow that.  
##### Use the below address to login to the GitLab UI.
``` shell script
http://<Public-IP>:80
``` 

By default the username is: root. And the default password that was set is "changeme". You can update this password in the shell script(gitlab-setup.sh) under "/shell directory." 
