# fargate-dns-updater

This Docker image will point a Route53 A record to the IP of a Fargate task.

Fargate doesn't currently support Elastic IP's, so normally the only way to access a Fargate web service with a consistent DNS name is to put a load balancer in front of the service. This is fine for highly available production workloads, but paying for a load balancer might be cost prohibitive for hobby workloads where you don't really care about high availability. This Docker image can be used as a workaround to provide something similar to dynamic DNS.

This Docker image is meant to be run as a sidecar container in a Fargate task. When the task spins up, it will detect it's own IP of the Fargate task, and then update a Route53 A record to point to that IP. Then the sidecar container will stop.

## Usage

### IAM permissions

Your task's [IAM role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html) will need the following permissions to make this work:

```
{
  "Statement": [
    {
      "Sid": "FargateDnsUpdater",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeTasks",
        "ec2:DescribeNetworkInterfaces",
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": ["*"]
    }
  ]
}
```

### Variables

The following environment variables should be injected into the container definition for this task, as a means of specifying the DNS record to be created.

| **Variable name** | **Description**                                                                                                          | **Example**                                                                       | **Required** | **Default** |
|:-----------------:|:------------------------------------------------------------------------------------------------------------------------:|:---------------------------------------------------------------------------------:|:------------:|:-----------:|
| `DNS_NAME`        | The DNS name to be updated                                                                                               | `example.com`, or `www.example.com`                                               | Yes          | None        |
| `HOSTED_ZONE_ID`  | The hosted zone ID to be updated                                                                                         | `Z3M3LMPEXAMPLE`                                                                  | Yes          | None        |
| `TTL`             | The TTL to use for the DNS record, specified in seconds                                                                  | 300                                                                               | No           | 300         |
| `USE_PRIVATE_IP`  | Set this to `"true"` if you want to point an A record to the private IP of a task. Otherwise the public IP is used.      | `"true"`                                                                          | No           | None        |

### Other useful parameters for your task definition

Set `"essential": false` in the container definition for this sidecar container, since it will exit after it has created the desired record.

Set the logs for this to go to Cloudwatch logs so you can see what it's doing and troubleshoot any errors.

### Example task definition

Below is an example task definition to illustrate how you would run this. Many parameters have been excluded for brevity.

```
{
    "networkMode": "awsvpc",
    "containerDefinitions": [
        {
            "name": "fargate-dns-updater",
            "image": "jwr0/fargate-dns-updater:latest",
            "essential": false,
            "environment": [
                {
                    "name": "DNS_NAME",
                    "value": "example.com"
                },
                {
                    "name": "HOSTED_ZONE_ID",
                    "value": "Z3M3LMPEXAMPLE"
                }
            ]
        },
        {
            "name": "some-other-service-which-runs-on-example.com",
            "image": "nginx:latest",
            "essential": true
        }
    ]
    "requiresCompatibilities": [
        "FARGATE"
    ]
}
```
