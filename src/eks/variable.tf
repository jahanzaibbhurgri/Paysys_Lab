variable "vpc_id" {
  type = string
}



variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "user_data1" {
  type    = string
  default = <<EOF
#!/bin/bash

# Variables
NAMESPACE="default"  # Replace with your namespace
MAX_RETRIES=3
TIMEFRAME=600  # 10 minutes in seconds

# Function to check pod status
check_pods() {
    kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running -o json | jq -r '.items[] | select(.status.containerStatuses[].restartCount > '$MAX_RETRIES') | .metadata.name'
}

# Function to restart a pod
restart_pod() {
    local pod_name=$1
    kubectl delete pod $pod_name -n $NAMESPACE
    echo "$(date): Restarted pod $pod_name" >> $LOGFILE
}

# Main loop
while true; do
    # Get pods with failure counts
    failing_pods=$(check_pods)

    if [[ ! -z "$failing_pods" ]]; then
        for pod in $failing_pods; do
            restart_pod $pod
        done
    fi

    # Log current pod statuses
    echo "$(date): Checked pods in $NAMESPACE" >> $LOGFILE
    kubectl get pods -n $NAMESPACE >> $LOGFILE
    
    # Wait before the next check
    sleep $TIMEFRAME
done
EOF
}
