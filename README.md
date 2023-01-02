# Auto Scale EC2 using SQS

## Table of Contents

1. [Introduction](#Intro)
2. [Create an EC2 Instance Role](#Role)
3. [Create a Key pair](#KP)
4. [Create a Security Group](#SG)
5. [Create a S3 Bucket](#S3)
6. [Create a SQS queue](#sqs)
7. [Create a Cloud9 instance](#cloud9)
8. [Create CloudWatch Alarms](#cw)
7. [Create a Launch Template](#template)
8. [Create an Auto Scaling Group](#ASG)
9. [Verification and Monitoring](#verify)
10. [Clean Up](#cleanup)
11. [Summary](#summary)
12. [Referrals](#referrals)

<a name="Intro"></a>

### Introduction

In this blog we are going to set up auto scaling of EC2 instances using the SQS ApproximateNumberOfMessagesVisible metric.

AWS Auto Scaling monitors your applications and automatically adjusts capacity to maintain steady, predictable performance at the lowest possible cost. Using AWS Auto Scaling, it’s easy to setup application scaling for multiple resources across multiple services in minutes.

#### Benefits
- Setup Scaling quickly.
- Make SMART scaling decisions.
- Automatically maintain performance.
- Pay only for what you need.

---

### Demo

Let's get started with the demo.

<a name="Role"></a>

#### Step 1. Create an EC2 Instance Role

1. Navigate to IAM > Roles > Click on **Create role**
2. Select **EC2** under Common use case and Click **Next**
3. Select **AmazonS3ReadOnlyAccess** and **AmazonSQSFullAccess** and Click **Next**
   > Note: you may create a custom policy for SQS with the required permissions instead of using a managed policy **AmazonSQSFullAccess** to provide the least amount of privileges.
4. Enter Role name as **EC2InstanceRoleForSQS** and Click **Create role**

    _AmazonSQSFullAccess_

    ```json
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sqs:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
    }
    ```

    _AmazonSQSFullAccess_

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:Get*",
                    "s3:List*",
                    "s3-object-lambda:Get*",
                    "s3-object-lambda:List*"
                ],
                "Resource": "*"
            }
        ]
    }
    ```

    _Trusted entities_

    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    ```

---

<a name="KP"></a>

#### Step 2. Create a key pair

1. Navigate to EC2 > Key Pairs (under Network & Security).
2. Click `Create key pair`.
3. Enter Name as `auto-scale`.
4. Navigate to the folder where the key pair is downloaded and run.
   
   ```bash
   chmod 400 <key_pair_name>.pem
   ```

![Auto_Scale_Keypair](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/cj672rfyzguxznfuwi2t.png)
> Auto_Scale_Keypair

---

<a name="SG"></a>

#### Step 3. Create a Security Group

1. We are going to create a Security Group for SSH.
2. Navigate to EC2 > Security Groups > Create a new security group for your ALB, and set the following values:
   * Name: `MyIPSSH-SG`.
   * Add an Inbound rule to allow `SSH (TCP 22)` traffic from `My IP`.

![MyIPSSH-SG](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/br62zaedgkg28yx8u12g.png)
> MyIPSSH-SG

---

<a name="S3"></a>

#### Step 4. Create a S3 Bucket
1. Navigate to EC2 > Click **Create Bucket**
2. Enter Bucket name as `autoscalescripts`, probably add some random numbers to make the bucket name unique.
3. Leave the rest of the settings as default and click **Create Bucket**
4. Download `sendMessages.sh` and `receiveMessages.sh` from the [github](https://github.com/kasukur/auto-scale-ec2-using-sqs) and upload them to the S3 bucket.

---

<a name="sqs"></a>

### Step 5. Create a SQS queue

1. Navigate to **Simple Queue Service** and click **Create queue**
2. Enter **Name** as `MyMessages`, leave the rest as defaults and click **Create queue**


![SQS_1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/2840jonlzd6rcvmtlhjr.png)
> SQS_1

![SQS_2](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/f0hc7eqa4g80wskip1i8.png)
> SQS_2

![SQS_3](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/fsrlwh25smnutkqh6nw4.png)
> SQS_3

![SQS_4](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/9cxuzg9jeq12ab6vi42x.png)
> SQS_4

---

<a name="cloud9"></a>

### Step 6. Create a Cloud9 instance

1. Navigate to **Cloud9** > **Create Environment**.
2. Enter **Name** as `awscli` and click **Create**.
3. Click **Open** under **AWS Cloud9** > **Environments**.
4. When Cloud9 is ready, Click File > Upload Local Files... and then upload `sendMessages.sh`.
5. Let's check aws cli version.

    ```bash
    Sri:~/environment $ aws --version
    aws-cli/1.19.112 Python/2.7.18 Linux/4.14.301-224.520.amzn2.x86_64 botocore/1.20.112
    ```

6. The script uses `jq`, so we need to install `jq`.
7. Open a Terminal and execute `sudo yum install jq -y`.
8. Execute `chmod +x sendMessages.sh` to provide the execute permissions.
9. Now run the script to send **2000** messages to `MyMessages` queue.

> Note: Alternatively you could use AWS CLI on your personal computer to send the messages.

---

<a name="cw"></a>

### Step 7. Create CloudWatch Alarms

We are going to create a ScaleOut Alarm to launch new instances when the **ApproximateNumberOfMessagesVisible** are greater than **500**.

1. Navigate to CloudWatch > Alarms > Click **Create alarm**.
2. Click **Select Metric**, search for **SQS**, select **SQS > Queue Metrics**, Select **MyMessages > ApproximateNumberOfMessagesVisible** and Click **Select Metric**.
3. Change **Statistic** to **Sum**, **Period** to **1 minute**.
    - Threshold type: **Static**.
    - Whenever ApproximateNumberOfMessagesVisible is...: **Greater**.
    - Define the threshold value: **500**.
4. Click **Next**.
5. Click **Remove** under **Notification** and Click **Next**.
6. Enter Alarm name as **ScaleOut** and Click **Next**.
7. Click **Create Alarm**.

Similar to ScaleOut, we also need to create a ScaleIn Alarm to launch new instances when the **ApproximateNumberOfMessagesVisible** are lesser than **300**.

1. Select **ScaleOut** from CloudWatch > Alarms, Click on **Actions** and **Copy**.
2. Change the following:
    - Whenever ApproximateNumberOfMessagesVisible is...: **Lower**.
    - Define the threshold value: **300**.
4. Click **Next**.
5. Click **Remove** under **Notification** and Click **Next**.
6. Enter Alarm name as **ScaleIn** and Click **Next**.
7. Click **Create Alarm**.

👉 It is important to not to have the same value for scale-in and scale-out thresholds. we you should leave a gap between them to prevent oscillation.
For example: let's say you have 3 instances, and the CPU goes to 60%, triggering the +1 step scaling policy. If the load stays constant, it will now be distributed to all 4 instances and the average CPU will drop to around 45% and the scale-in alarm will go off. This will then keep happening in a loop until the load goes up or down enough for one of the alarms to stay in the alarm state and the ASG reaches the min or max.


![ScaleOut_CreateAlarm1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/3pt9c5atzk7rk9yg9bbo.png)
> ScaleOut_CreateAlarm1

![ScaleOut_CreateAlarm2](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/l5u55wcnn7n4rl9uxdig.png)
> ScaleOut_CreateAlarm2

![ScaleOut_CreateAlarm3](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/es5938dpg564pac6jefl.png)
> ScaleOut_CreateAlarm3

![ScaleOut_CreateAlarm4](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/inxbaifgkcyyy0d6ara4.png)
> ScaleOut_CreateAlarm4

![ScaleOut_CreateAlarm5](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/k98eiuqaeibjpax72gmq.png)
> ScaleOut_CreateAlarm5

![Image description](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/qcacp6l6siopwcwgbgds.png)
> ScaleOut_CreateAlarm6

![ScaleOut_CreateAlarm7](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/hwue82oizjtbp6t6hx1x.png)
> ScaleOut_CreateAlarm7

![ScaleOut_CreateAlarm7.1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/e0iozatxchop2oyfbfbk.png)
> ScaleOut_CreateAlarm7.1


![ScaleIn_CreateAlarm1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/46ribyq66ddw5msbj1a3.png)
> ScaleIn_CreateAlarm1

![ScaleIn_CreateAlarm2](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/fon9gl7kgyjmi05weo9k.png)
> ScaleIn_CreateAlarm2

![ScaleIn_CreateAlarm3](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/15s0i1jkkbouohwxogt5.png)
> ScaleIn_CreateAlarm3

![ScaleIn_CreateAlarm4](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/b93zwazzvilpgs4twq8s.png)
> ScaleIn_CreateAlarm4

![ScaleIn_CreateAlarm4.1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/hrrxkco7eygw9d5am5i6.png)
> ScaleIn_CreateAlarm4.1

---

<a name="template"></a>

### Step 8. Create a Launch Template

We can use Launch template or Launch Configurations. Launch Template are preferred over Launch Configurations as we can have different versions of the template. Also we can't modify a launch configuration after we have created it.

Create a launch template that will be used by the Auto Scaling group. The launch template defines what the instances are and how they are created.

1. Navigate to EC2 > Instances > Launch Templates.
2. Create a new template, and call it `AutoScale-SQS` for the name.
3. Select `Provide guidance to help me set up a template that I can use with EC2 Auto Scaling`
4. Search for `AMI`, and pick the `Amazon Linux`.
5. Set the instance type as `t2.micro`.
6. Select `key pair` you created earlier.
8. Select the `MyIPSSH-SG` security group you created earlier.
9. Expand Advanced Details, and select `EC2InstanceRoleForSQS` Role under **IAM instance profile**.
10. Paste the following script under **User data**.
    * Note: These are commands to install jq, aws cli, copy scripts from S3 bucket and executes receiveMessages.sh.
10. Click Create Launch Template.
11. Click **View Launch templates**.

**User data**

> Note: Please update the bucket name in the script.

```bash
#!/bin/bash
# install jq
sudo yum install jq -y
# Update aws cli version
cd /home/ec2-user
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
which aws
ls -l /usr/local/bin/aws
aws --version
# copy sendMessages.sh and receiveMessages.sh from S3
aws s3 cp s3://sqssri/ . --recursive --exclude "*" --include "*.sh"
sudo chmod +x /home/ec2-user/*.sh
nohup ./receiveMessages.sh &
```

👉 Launch templates with User data are slow, it is recommended to create an AMI with the required software to improve the speed of instance initialisation.

![LaunchTemplate1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/7xbrn9ucrk4ppmti5prl.png)
> LaunchTemplate1

![LaunchTemplate1.1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/yjgeub5zdtzcro7p2g8v.png)
> LaunchTemplate1.1

![LaunchTemplate1.2](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/ye8vy4fvzxxjk6ujkhx7.png)
> LaunchTemplate1.2

![LaunchTemplate1.3](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/zq1oz6djdp5hundl6ceq.png)
> LaunchTemplate1.3

![LaunchTemplate1.4](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/2k1m4xq1xa827tyi67r3.png)
> LaunchTemplate1.4

---

<a name="ASG"></a>

### Step 9. Create an Auto Scaling Group

1. Navigate to EC2 > Auto Scaling > Auto Scaling Groups
2. Click **Create Auto Scaling group**.
3. Call the group `ASG-SQS`.
4. Select Launch Template, and choose the template named `AutoScale-SQS`.
5. We are using `default VPC`, which will be selected, so select `us-east-1a` as subnet.
7. Click Next.
8. Leave the default for Health checks, which is `EC2`.
9. Leave the default for Configure advanced options and Click Next.
10. For Group Size, enter the following values:
    * Desired Capacity: `1`
    * Minimum Capacity: `1`
    * Maximum Capacity: `4`
11. We will not be adding Scaling policies here, so leave the default `None` and Click Next.
12. Click Next at `Add Notifications`.
13. Click Next at `Add tags`.
14. Click Create `Auto Scaling Group`.
15. Navigate to EC2 > Auto Scaling > click `ASG-SQS` and then click `Automatic scaling`
16. We are going to add two dynamic scaling policies, one for scale out and another one for scale in. Click **Create dynamic scaling policy** and enter the following values and then Click **Create**:
    * Policy type: `Simple Scaling`
    * Scaling policy name: `ScaleOut`
    * CloudWatch alarm: `ScaleOut`
    * Take the action: `Add` with `1` capacity units
    * And then wait `60` seconds before allowing another scaling activity
17. Click **Create dynamic scaling policy** and enter the following values and then Click **Create**:
    * Policy type: `Simple Scaling`
    * Scaling policy name: `ScaleIn`
    * CloudWatch alarm: `ScaleIn`
    * Take the action: `Remove` with `1` capacity units
    * And then wait `120` seconds before allowing another scaling activity

👉 The best practice is to scale up fast and scale down slow. Hence we used 60 seconds to scale out and 120 seconds to scale in.

![ASG1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/rkzh595bvg4q44v9x4c3.png)
> ASG1

![ASG2](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/ltpxo3028i289y907b3g.png)
> ASG2

![ASG3](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/j75emf9kpsq8ajqt6lup.png)
> ASG3

![ASG4](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/head3g2ex0o8v7wufxhg.png)
> ASG4

![ASG5](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/6fo8oixbltgppgi7l9j3.png)
> ASG5

![ASG6](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/gakx52qryz95vejtd8e6.png)
> ASG6

![ASG7](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/i2nczeve56mfsg5x3nm8.png)
> ASG7

![ASG7.1](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/eo2i142vkuqlyd9j50el.png)
> ASG7.1

![ASG7.2](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/5yrbf6c9s39z6q1us0uo.png)
> ASG7.2

![ASG8](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/94zljs854lutt51eu7vr.png)
> ASG8

![ASG8.1_ScaleOut](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/xrmcytl7g9d0veax50x9.png)
> ASG8.1_ScaleOut

![ASG8.2_ScaleIn](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/luk13ce7usne6sj96nxx.png)
> ASG8.2_ScaleIn

![ASG8.3_Dynamic_Scaling](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/swwi96gnopgfor4qtgsf.png)
> ASG8.3_Dynamic_Scaling

---

<a name="verify"></a>

### Step 10. Verification and Monitoring

Since we have populated the queue with 2000 messages and have an auto scaling group launch a maximum of 4 instances.
We will be verifying it using Cloud Watch Alarms and Auto Scaling group's Activity.

1. Navigate to CloudWatch > Alarms > ScaleOut, the state of ScaleOut ALarm status will be `In alarm` and the ScaleIn ALarm status will be `OK`.
2. After a period of 10 mins or so, you will notice 4 EC2 instances launched under EC2 > Auto Scaling groups > ASG-SQS > Activity.
3. Monitor the messages in `MyMessages` queue, the number of messages will be reducing as they are processed by the EC2 instances.
4. Navigate to CloudWatch > Alarms > ScaleOut, the state of ScaleOut ALarm status will be `OK` and the ScaleIn ALarm status will be `In alarm`.
5. You will notice 3 EC2 instances terminated under EC2 > Auto Scaling groups > ASG-SQS > Activity.

#### How to verify that the SQS messages are being processed?

Logon to the EC2 Instance and then switch to the root user.

```bash
[ec2-user@ip-172-31-47-21 ~]$ sudo su -
```

Execute the following command, which will show the log file.

```bash
ps xf
```

```bash
[root@ip-172-31-47-21 ~]# tail -f /var/log/cloud-init-output.log
Sleep for 1 second...
Sleep for 1 second...
Sleep for 1 second...
Sleep for 1 second...
^C
```

![Messages_in_the_queue](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/qdto7k32ruxcj43mroww.png)
> Messages_in_the_queue

![ScaleOut_Alarm](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/0d81ihvzv12obsxlmwz9.png)
> ScaleOut_Alarm

![ScaleOut_Activity](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/egncwgp70ou8qpnr11hh.png)
> ScaleOut_Activity

![Processing_Messages](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/4qgq4iooufewhoz5t9wr.png)
> Processing_Messages

![ScaleIn_Alarm](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/b6e3aspvrglespoihu5a.png)
> ScaleIn_Alarm

![ScaleIn_Activity](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/y4bwqzluwjoisbjyeaio.png)
> ScaleIn_Activity

![Queue_is_Empty](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/xxfm2pjbazi7ene2j651.png)
> Queue_is_Empty

---

👉 Auto Scaling Group Tip: When you do not want to have instances running or for Disaster Recovery purposes or to save costs, you may set the following to **Zero**.
- Desired Capacity: `0`
- Minimum Capacity: `0`
- Maximum Capacity: `0`

![ASG_Tip](https://dev-to-uploads.s3.amazonaws.com/uploads/articles/5u8aclozbbqtnp7whyg6.png)
> ASG_Tip

---

<a name="cleanup"></a>

### Clean Up

1. Terminate `Cloud9` EC2 instance.
2. Delete `ASG-SQS` under `Auto Scaling groups`.
3. Delete `AutoScale-SQS` under `Launch Templates`
4. Delete `auto-scale` under `Key Pairs`
5. Delete Security Group `MyIPSSH-SG`.
6. Delete `EC2InstanceRoleForSQS` Role under IAM.
7. Delete S3 bucket `autoscalescripts`.
8. Delete SQS queue `MyMessages`.

---

<a name="summary"></a>

### Summary

👉 It is important to not to have the same value for scale-in and scale-out thresholds. we you should leave a gap between them to prevent oscillation.

👉 The best practice is to scale up fast, and scale down slow.

👉 Launching an EC2 instance might be slow if we have to install software, configure..etc during the scale out. One way to speed up the process is by creating an AMI with all the required software and then use that AMI in the Launch template.

See you next time 👋

---

<a name="referrals"></a>

### Referrals

- [Scaling based on Amazon SQS](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-using-sqs-queue.html)