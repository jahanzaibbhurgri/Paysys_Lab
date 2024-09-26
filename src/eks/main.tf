#creating the role
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

resource "aws_eks_cluster" "eks" {

  name = "eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version = "1.24" #do check for latest
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

//eks-worker-nodes

# role created
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

# Create a launch template
resource "aws_launch_template" "eks_worker_nodes" {
  name_prefix   = "eks-worker-nodes-"
  image_id      = "ami-04a81a99f5ec58529"  # Replace with the appropriate AMI ID
  instance_type = "t3.small"

  user_data = data.template_file.user_data.rendered

  iam_instance_profile {
    name = aws_iam_role.nodes_general.name
  }

  lifecycle {
    create_before_destroy = true
  }
}


#3 polices are attached to the worker nodes
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
/*
AmazonEKSWorkerNodePolicy: This policy is necessary for EKS worker nodes to communicate with the EKS control plane.
AmazonEKS_CNI_Policy: This policy is required for the Amazon VPC CNI plugin, which allows pods to get IP addresses from the VPC.
AmazonEC2ContainerRegistryReadOnly: This policy allows nodes to pull container images from Amazon ECR. It's a valid policy for EKS nodes.
*/


resource "aws_eks_node_group" "nodes_general" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "nodes-general"
  node_role_arn   = aws_iam_role.nodes_general.arn
  subnet_ids      = [
    var.private_subnet_ids[0], 
    var.private_subnet_ids[1], // using the worker nodes to deploy on the private subnet 
  ]
  // will deploy the load balancer on the public subnet //

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  
    launch_template {
    id      = aws_launch_template.eks_worker_nodes.id
    version = "$Latest"
  }
  
  // capacity type can be ON_DEMAND or SPOT
  capacity_type = "ON_DEMAND"
  
  disk_size     = 20
  
  // Ensure the correct use of instance types
  instance_types = ["t3.small"]

  
  labels = {
    role = "nodes-general"
  }
  
  // Specify the version for the node group if needed
  version = "1.24"  // You might want to specify a version or leave it blank for the latest

  update_config {
    max_unavailable = 1
  }
  

  // Ensure that IAM Role permissions are created before the EKS Node Group handling
  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy_general,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy_general,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]
}


#now deploying the nginx application through the terraform
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