# ecs_airflow

<h2>
  Diagram
</h2>

![alt text](https://github.com/tigstep/ecs_airflow/blob/master/diagrams/aws_ecs_diagram.jpg)
<h2>
  Requirements
</h2>
  Requires Terraform and an AWS account.
<h2>
  Tools/Services Used
</h2>
  <ul>
  <li>Docker</li>
  <li>Terraform</li>
  <li>Apache Airflow</li>
  <li>AWS</li>
    <ul>
      <li>ECS</li>
    </ul>
  </ul>
<h2>
  Short Description
</h2>  
A project that sets up an AWS ECS infrastructure and hosts an Apachi Airflow running inside a docker container.
<h2>
  Process Description
</h2>
  The entire process is automated using Terraform. Below are the steps
  <ol>
    <li>A VPC is created</li>
    <li>2 Subnets are created inside the above VPC</li>
    <ol type="i">
      <li>An internet gateway is created</li>
      <li>A route table is created</li>
      <li>The above Internet Gateway is associated to the above subnets(making them public), using the route table</li>
    </ol>
    <li>A Security Group is created to be used with ECS Instances</li>
    <li>ECS Service Role and ECS Instance Role are created to insure necessary permissions for the ECS service</li>
    <li>An Application Load Balancer is created to act as a "starting point" for the requests to the airflow docker container</li>
    <li>A Listener is created, along with a Target Group to route all the Application Load Balancer requests to that Target Group</li>
    <li>A Launch Configuration is created for the ECS Instances, along with an Autoscaling Group to use the Launch Configuration to keep the ECS Instances count equal to the desired count</li>
    <li>An ECS Cluster is Created</li>
    <li>A container definition is created separatly to be used while creating an ECS task</li>
    <li>An ECS Task is definied using the above Container Definition</li>
    <li>An ECS Service is created using the above ECS Task Definition</li>
  </ol>
<h2>
  Execution
</h2>
In order to execute, modify the varriable.tfvar file with proper variables and run <br>
<b>terraform apply -var-file=variables.tfvars && terraform output -json > outputs.json</b><br>
In order to tear down the infrastructure, run <br>
<b>terraform destroy -var-file=variables.tfvars</b>
<h2>
  To Do
</h2>
  <ul>
    <li>Automatically push the DAG's from S3</li>
    <li>Revisit the key_pair creation process</li>
    <li>Improve Parametrization and add descriptions to tfvars</li>  
  </ul>
<h2>
  Nice To Have
</h2>
  <ul>
    <li>Remote s3 logging</li>
  </ul>
<h2>
  Warnings
</h2>
  Current configuration of this project will be using AWS services that are beyond the Free Tier!
