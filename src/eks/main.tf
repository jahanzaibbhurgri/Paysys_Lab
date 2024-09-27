//main.tf//

resource "aws_iam_role" "eks_cluster" {
  name               = "eks-cluster-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" 
  role       = aws_iam_role.eks_cluster.name
}

#2.2 Deploy the kubernetes using the terraform

resource "aws_eks_cluster" "eks" {

  name = "eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version = "1.24" 
  vpc_config {
	endpoint_private_access = false
        endpoint_public_access = true 
        subnet_ids = [
      var.public_subnet_ids[0],  
      var.public_subnet_ids[1], 
      var.private_subnet_ids[0], 
      var.private_subnet_ids[1],  
	
      ]	

  }
  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_cluster_policy
  ]
}

//this is the scripting task 
#2.3 scripting task

resource "aws_iam_role" "nodes_general" {
  name               = "eks-node-group-general"
  assume_role_policy = <<POLICY
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
POLICY
}

#2.3 Script(s) that create the infrastructure and deploy the application.


data "template_file" "user_data" {
  template = <<EOF
#!/bin/bash

# Variables
NAMESPACE="default"  # Replace with your namespace
LOGFILE="/var/log/my_script.log"  # Path to log file
MAX_RETRIES=3
TIMEFRAME=600  # 10 minutes in seconds

# Function to check pod status
check_pods() {
    kubectl get pods -n \$NAMESPACE --field-selector=status.phase!=Running -o json | jq -r '.items[] | select(.status.containerStatuses[].restartCount > \$MAX_RETRIES) | .metadata.name'
}

# Function to restart a pod
restart_pod() {
    local pod_name=\$1
    kubectl delete pod \$pod_name -n \$NAMESPACE
    echo "\$(date): Restarted pod \$pod_name" >> \$LOGFILE
}

# Main loop
while true; do
    # Get pods with failure counts
    failing_pods=\$(check_pods)

    if [[ ! -z "\$failing_pods" ]]; then
        for pod in \$failing_pods; do
            restart_pod \$pod
        done
    fi

    # Log current pod statuses
    echo "\$(date): Checked pods in \$NAMESPACE" >> \$LOGFILE
    kubectl get pods -n \$NAMESPACE >> \$LOGFILE
    
    # Wait before the next check
    sleep \$TIMEFRAME
done
EOF
}

//configured the template and attached the scripting task this template so whenever the worker node is initalized so this script would
//automatically be deployed to the workernodes and i have attached the template to the worker node
resource "aws_launch_template" "eks_worker_nodes" {
  name_prefix   = "eks-worker-nodes-"
  image_id      = "ami-04a81a99f5ec58529" 
  instance_type = "t3.small"

  user_data = data.template_file.user_data.rendered

  iam_instance_profile {
    name = aws_iam_role.nodes_general.name
  }

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy_general" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes_general.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy_general" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes_general.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes_general.name
}


//configured the worker nodes in the private subnet //

resource "aws_eks_node_group" "nodes_general" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "nodes-general"
  node_role_arn   = aws_iam_role.nodes_general.arn
  subnet_ids      = [
    var.private_subnet_ids[0], 
    var.private_subnet_ids[1], 
  ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  
    launch_template {
    id      = aws_launch_template.eks_worker_nodes.id
    version = "$Latest"
  }
  

  capacity_type = "ON_DEMAND"
  
  disk_size     = 20
  

  instance_types = ["t3.small"]

  
  labels = {
    role = "nodes-general"
  }
  
  
  version = "1.24"  

  update_config {
    max_unavailable = 1
  }
  


  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy_general,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy_general,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]
}




/*
2.2 Set up a Load Balancer and configure it to expose the application on port 80.
•
2.2 Deploy the web application (a simple Nginx or similar container) into the Kubernetes cluster.
*/

//so in this i have configured the i have deployed the nginx pod with two services(one for public load balancer and other one as a private loadbalancer)
//which is exposed on the port 80 pod as well as the services is exposed on the port 80//

provider "kubernetes" {
  host                   = aws_eks_cluster.eks.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority[0].data)
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks.name
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx"
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.4.2"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "internal_nginx_service" {
  metadata {
    name = "internal-nginx-service"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                        = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
      "service.beta.kubernetes.io/aws-load-balancer-internal"                     = "true" 
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.nginx.metadata[0].name
    }

    type = "LoadBalancer"

    port {
      protocol = "TCP"
      port     = 80
    }
  }
}

resource "kubernetes_service" "external_nginx_service" {
  metadata {
    name = "external-nginx-service"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                        = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.nginx.metadata[0].name
    }

    type = "LoadBalancer"

    port {
      protocol = "TCP"
      port     = 80
    }
  }
}