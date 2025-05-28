# Kubernetes Workshop for Bioinformaticians

Welcome to this hands-on Kubernetes workshop designed specifically for bioinformatics workflows. This workshop will guide you through the fundamentals of Kubernetes and provide practical templates for common bioinformatics use cases.

## Structure

1. Introduction to Kubernetes: 15 minutes presentation about the core principles of Kubernetes and our concrete cluster
2. Demonstration: 15 minutes of demonstration how to work with Kubernetes (only requirement: working kubectl + config) - showcase the 3 usecases - in a nutshell - what to expect from those examples
3. Practical Session: 30 minutes of reproducing 1 blueprint for each participant

## Prerequisites for the practical session

- Basic command line knowledge
- Docker concepts (containers, images)
- Access to the provided Kubernetes cluster
- `kubectl` installed and configured

## Setup

1. Clone this repository
2. Copy `.env.example` to `.env` and fill in your specific values
3. Source your environment variables: `source .env`

---

## 1. Kubernetes Overview

### What is Kubernetes?

Kubernetes (K8s) is a container orchestration platform that automates the deployment, scaling, and management of containerized applications. Think of it as a sophisticated cluster manager that:

- **Schedules** containers across multiple machines
- **Manages** application lifecycle and health
- **Scales** applications up or down based on demand
- **Provides** networking and storage abstractions
- **Handles** rolling updates and rollbacks

### Core Architecture

![Kubernetes Cluster Architecture](./images/kubernetes-cluster-architecture.svg)

### Key Benefits for Bioinformatics

- **Resource Efficiency**: Share compute resources across multiple analyses
- **Scalability**: Scale compute-intensive jobs automatically
- **Reproducibility**: Consistent environments across development and production
- **Isolation**: Separate different projects and users
- **GPU Management**: Efficient allocation of expensive GPU resources

### Basic kubectl Commands

```bash
# Check cluster info
kubectl cluster-info

# View nodes in the cluster
kubectl get nodes

# Check your current context and namespace
kubectl config current-context
kubectl config view --minify --output 'jsonpath={..namespace}'
```

**Exercise**: Run the above commands to familiarize yourself with the cluster.

---

## 2. Our Kubernetes Cluster

### Cluster Overview

Our bioinformatics cluster is configured with the following specifications:

```bash
# Get detailed node information
kubectl get nodes -o wide

# Check node resources and allocations
kubectl describe nodes

# View available resources
kubectl top nodes
```

### Node Types

**CPU Nodes**:

- High-memory nodes optimized for memory-intensive bioinformatics applications
- Suitable for genome assembly, large-scale sequence alignment
- Node selector: `node-type=cpu-optimized`

**GPU Nodes**:

- NVIDIA GPUs for deep learning and GPU-accelerated bioinformatics tools
- Limited number - use efficiently!
- Node selector: `node-type=gpu-enabled`

### Storage Classes

```bash
# View available storage classes
kubectl get storageclass

# Check persistent volumes
kubectl get pv
```

**Exercise**: Explore the cluster resources and identify which nodes are available for your workloads.

---

## 3. Namespaces: Isolation vs Sharing

### What are Namespaces?

Namespaces provide virtual clusters within your physical cluster. They're essential for:

- **Multi-tenancy**: Separate different users/projects
- **Resource quotas**: Limit resource consumption per project
- **Access control**: Control who can access what
- **Organization**: Keep related resources together

### Namespace Strategy for Bioinformatics

```bash
# List all namespaces
kubectl get namespaces

# Get resources in a specific namespace
kubectl get all -n ${NAMESPACE}

# Set default namespace for your session
kubectl config set-context --current --namespace=${NAMESPACE}
```

### Working with Namespaces

```yaml
# namespace-template.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    project: ${PROJECT_NAME}
    user: ${USERNAME}
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${NAMESPACE}-quota
  namespace: ${NAMESPACE}
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 100Gi
    limits.cpu: "40"
    limits.memory: 200Gi
    persistentvolumeclaims: "10"
```

**Exercise**:

1. Check which namespace you're assigned to
2. Explore the resources in your namespace
3. Set your namespace as the default context

---

## 4. Core Kubernetes Objects

### Pods: The Basic Unit

A **Pod** is the smallest deployable unit in Kubernetes:

- Contains one or more containers
- Shares network and storage
- Ephemeral by nature
- Usually managed by higher-level objects

```bash
# View pods in your namespace
kubectl get pods

# Describe a specific pod
kubectl describe pod <pod-name>

# Get pod logs
kubectl logs <pod-name>

# Execute commands in a pod
kubectl exec -it <pod-name> -- /bin/bash
```

**Example Pod**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bioinf-test-pod
  namespace: ${NAMESPACE}
spec:
  containers:
    - name: ubuntu
      image: ubuntu:20.04
      command: ["/bin/sleep", "3600"]
      resources:
        requests:
          memory: "1Gi"
          cpu: "0.5"
        limits:
          memory: "2Gi"
          cpu: "1"
```

### Deployments: Managing Pod Replicas

**Deployments** manage a set of identical pods:

- Ensure desired number of replicas
- Handle rolling updates
- Provide rollback capabilities
- Best for stateless applications

```bash
# View deployments
kubectl get deployments

# Scale a deployment
kubectl scale deployment <deployment-name> --replicas=3

# Check rollout status
kubectl rollout status deployment/<deployment-name>

# View deployment history
kubectl rollout history deployment/<deployment-name>
```

**When to use**: Stateless bioinformatics tools, web services, API servers

### StatefulSets: For Stateful Applications

**StatefulSets** manage stateful applications:

- Stable, unique network identifiers
- Stable, persistent storage
- Ordered, graceful deployment and scaling
- Ordered, automated rolling updates

```bash
# View statefulsets
kubectl get statefulsets

# Describe a statefulset
kubectl describe statefulset <statefulset-name>
```

**When to use**: Databases, Jupyter notebooks with persistent storage, applications requiring stable network identity

### Ingress: External Access

**Ingress** manages external access to services:

- HTTP/HTTPS routing
- SSL termination
- Virtual hosting
- Load balancing

```bash
# View ingress resources
kubectl get ingress

# Describe ingress rules
kubectl describe ingress <ingress-name>
```

**Exercise**:

1. Create the test pod above and explore it
2. Check if there are any deployments or statefulsets in your namespace
3. Look at the ingress configuration for external access

---

## 5. Data Access and Persistence

### Storage Types in Kubernetes

#### Ephemeral Storage

- **emptyDir**: Temporary storage, deleted when pod dies
- **hostPath**: Direct access to node filesystem (avoid in multi-node clusters)

#### Persistent Storage

- **PersistentVolume (PV)**: Cluster-wide storage resource
- **PersistentVolumeClaim (PVC)**: Request for storage by a user
- **StorageClass**: Dynamic provisioning of storage

### Data Access Patterns

#### 1. Mounting External Data (Read-Only)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: data-access-example
spec:
  containers:
    - name: analysis-container
      image: bioinformatics/tools:latest
      volumeMounts:
        - name: reference-data
          mountPath: /data/reference
          readOnly: true
        - name: input-data
          mountPath: /data/input
          readOnly: true
  volumes:
    - name: reference-data
      nfs:
        server: ${NFS_SERVER}
        path: /shared/reference-genomes
    - name: input-data
      nfs:
        server: ${NFS_SERVER}
        path: /shared/projects/${PROJECT_NAME}/input
```

#### 2. Persistent Storage for Results

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: analysis-results-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: ${STORAGE_CLASS}
---
apiVersion: v1
kind: Pod
metadata:
  name: analysis-with-persistence
spec:
  containers:
    - name: analysis-container
      image: bioinformatics/tools:latest
      volumeMounts:
        - name: results-storage
          mountPath: /results
        - name: temp-storage
          mountPath: /tmp/analysis
  volumes:
    - name: results-storage
      persistentVolumeClaim:
        claimName: analysis-results-pvc
    - name: temp-storage
      emptyDir:
        sizeLimit: 50Gi
```

### Best Practices for Data Management

1. **Use PVCs for persistent data** that needs to survive pod restarts
2. **Use emptyDir for temporary processing** data
3. **Mount reference data as read-only** to prevent accidental modifications
4. **Size your storage appropriately** - consider intermediate files
5. **Use appropriate storage classes** based on performance needs

**Exercise**:

1. Check available storage classes in your cluster
2. Look at existing PVCs in your namespace
3. Understand the data mounting strategy for your projects

---

## Use Cases

## Use Case 1: CPU-based Data Science Notebook (Jupyter)

### Motivation

Jupyter notebooks are essential for exploratory data analysis, visualization, and prototyping in bioinformatics. This setup provides:

- Persistent workspace that survives pod restarts
- Access to shared datasets and reference genomes
- Web-based access through ingress
- Customizable Python/R environment

### Architecture

```
Internet → Ingress → Service → StatefulSet → PVC
                                     ↓
                              Persistent Storage
```

### Deployment Template

```yaml
# jupyter-notebook.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${USERNAME}-jupyter
  namespace: ${NAMESPACE}
  labels:
    app: jupyter-notebook
    user: ${USERNAME}
spec:
  serviceName: ${USERNAME}-jupyter-service
  replicas: 1
  selector:
    matchLabels:
      app: jupyter-notebook
      user: ${USERNAME}
  template:
    metadata:
      labels:
        app: jupyter-notebook
        user: ${USERNAME}
    spec:
      nodeSelector:
        node-type: cpu-optimized
      containers:
        - name: jupyter
          image: jupyter/datascience-notebook:latest
          ports:
            - containerPort: 8888
          env:
            - name: JUPYTER_ENABLE_LAB
              value: "yes"
            - name: JUPYTER_TOKEN
              value: ${JUPYTER_TOKEN}
          resources:
            requests:
              memory: "4Gi"
              cpu: "2"
            limits:
              memory: "8Gi"
              cpu: "4"
          volumeMounts:
            - name: jupyter-workspace
              mountPath: /home/jovyan/work
            - name: shared-data
              mountPath: /data/shared
              readOnly: true
            - name: reference-genomes
              mountPath: /data/reference
              readOnly: true
      volumes:
        - name: shared-data
          nfs:
            server: ${NFS_SERVER}
            path: /shared/datasets
        - name: reference-genomes
          nfs:
            server: ${NFS_SERVER}
            path: /shared/reference-genomes
  volumeClaimTemplates:
    - metadata:
        name: jupyter-workspace
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: ${STORAGE_CLASS}
        resources:
          requests:
            storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ${USERNAME}-jupyter-service
  namespace: ${NAMESPACE}
spec:
  selector:
    app: jupyter-notebook
    user: ${USERNAME}
  ports:
    - port: 8888
      targetPort: 8888
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${USERNAME}-jupyter-ingress
  namespace: ${NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
    - hosts:
        - ${USERNAME}-jupyter.${CLUSTER_DOMAIN}
      secretName: ${TLS_SECRET_NAME}
  rules:
    - host: ${USERNAME}-jupyter.${CLUSTER_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${USERNAME}-jupyter-service
                port:
                  number: 8888
```

### Deployment Commands

```bash
# Set environment variables
export USERNAME="your-username"
export NAMESPACE="your-namespace"
export JUPYTER_TOKEN=$(openssl rand -hex 32)
export CLUSTER_DOMAIN="your-cluster-domain.com"
export STORAGE_CLASS="your-storage-class"
export NFS_SERVER="your-nfs-server-ip"
export TLS_SECRET_NAME="your-tls-secret"

# Deploy Jupyter notebook
envsubst < jupyter-notebook.yaml | kubectl apply -f -

# Check deployment status
kubectl get statefulset ${USERNAME}-jupyter -n ${NAMESPACE}
kubectl get pod -l app=jupyter-notebook -n ${NAMESPACE}

# Get access URL
echo "Jupyter notebook available at: https://${USERNAME}-jupyter.${CLUSTER_DOMAIN}"
echo "Token: ${JUPYTER_TOKEN}"

# Clean up when done
envsubst < jupyter-notebook.yaml | kubectl delete -f -
```

---

## Use Case 2: CPU-based Nextflow Pipeline

### Motivation

Nextflow is a popular workflow management system for bioinformatics pipelines. This setup provides:

- Scalable execution across the cluster
- Automatic job scheduling and resource management
- Integration with existing data storage
- Pipeline reproducibility and monitoring

### Architecture

```
Nextflow Head Pod → Kubernetes Executor → Worker Pods
       ↓                    ↓
 Config/Scripts      Scheduled Tasks
```

### Deployment Template

```yaml
# nextflow-pipeline.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ${PIPELINE_NAME}-${TIMESTAMP}
  namespace: ${NAMESPACE}
  labels:
    app: nextflow-pipeline
    pipeline: ${PIPELINE_NAME}
    user: ${USERNAME}
spec:
  ttlSecondsAfterFinished: 3600 # Clean up after 1 hour
  template:
    metadata:
      labels:
        app: nextflow-pipeline
        pipeline: ${PIPELINE_NAME}
        user: ${USERNAME}
    spec:
      restartPolicy: Never
      nodeSelector:
        node-type: cpu-optimized
      serviceAccountName: ${NAMESPACE}-nextflow-sa
      containers:
        - name: nextflow
          image: nextflow/nextflow:latest
          command: ["/bin/bash"]
          args:
            - -c
            - |
              # Configure Nextflow for Kubernetes
              export NXF_WORK=/workspace/work
              export NXF_ASSETS=/workspace/assets

              # Run the pipeline
              nextflow run ${PIPELINE_REPO} \
                -r ${PIPELINE_REVISION} \
                -profile kubernetes \
                --input ${INPUT_PATH} \
                --outdir ${OUTPUT_PATH} \
                ${PIPELINE_PARAMS}
          env:
            - name: NXF_EXECUTOR
              value: "k8s"
            - name: NXF_K8S_NAMESPACE
              value: ${NAMESPACE}
            - name: NXF_K8S_RUNASUSER
              value: "1000"
          resources:
            requests:
              memory: "2Gi"
              cpu: "1"
            limits:
              memory: "4Gi"
              cpu: "2"
          volumeMounts:
            - name: workspace
              mountPath: /workspace
            - name: input-data
              mountPath: /data/input
              readOnly: true
            - name: output-data
              mountPath: /data/output
            - name: reference-data
              mountPath: /data/reference
              readOnly: true
      volumes:
        - name: workspace
          emptyDir:
            sizeLimit: 10Gi
        - name: input-data
          nfs:
            server: ${NFS_SERVER}
            path: ${INPUT_NFS_PATH}
        - name: output-data
          nfs:
            server: ${NFS_SERVER}
            path: ${OUTPUT_NFS_PATH}
        - name: reference-data
          nfs:
            server: ${NFS_SERVER}
            path: /shared/reference-genomes
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${NAMESPACE}-nextflow-sa
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: ${NAMESPACE}
  name: nextflow-runner
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/status", "pods/log"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: nextflow-runner-binding
  namespace: ${NAMESPACE}
subjects:
  - kind: ServiceAccount
    name: ${NAMESPACE}-nextflow-sa
    namespace: ${NAMESPACE}
roleRef:
  kind: Role
  name: nextflow-runner
  apiGroup: rbac.authorization.k8s.io
```

### Nextflow Configuration

```groovy
// nextflow.config
profiles {
  kubernetes {
    process {
      executor = 'k8s'
      container = 'nfcore/base:latest'

      // Resource defaults
      cpus = 2
      memory = 4.GB
      time = 2.h

      // Kubernetes specific settings
      pod = [
        [nodeSelector: 'node-type=cpu-optimized'],
        [imagePullPolicy: 'Always']
      ]
    }

    // Process-specific configurations
    process {
      withLabel: 'high_memory' {
        memory = 32.GB
        cpus = 8
      }

      withLabel: 'long_running' {
        time = 24.h
      }
    }

    k8s {
      namespace = System.getenv('NXF_K8S_NAMESPACE')
      runAsUser = System.getenv('NXF_K8S_RUNASUSER') as Integer
      storageClaimName = 'nextflow-workspace-pvc'
      storageMountPath = '/workspace'
    }
  }
}
```

### Deployment Commands

```bash
# Set environment variables
export PIPELINE_NAME="rnaseq-analysis"
export PIPELINE_REPO="nf-core/rnaseq"
export PIPELINE_REVISION="3.0"
export TIMESTAMP=$(date +%Y%m%d-%H%M%S)
export INPUT_PATH="/data/input/*.fastq.gz"
export OUTPUT_PATH="/data/output"
export PIPELINE_PARAMS="--genome GRCh38 --aligner star"
export INPUT_NFS_PATH="/shared/projects/${PROJECT_NAME}/input"
export OUTPUT_NFS_PATH="/shared/projects/${PROJECT_NAME}/output"

# Deploy the pipeline
envsubst < nextflow-pipeline.yaml | kubectl apply -f -

# Monitor the pipeline
kubectl get job ${PIPELINE_NAME}-${TIMESTAMP} -n ${NAMESPACE}
kubectl logs -f job/${PIPELINE_NAME}-${TIMESTAMP} -n ${NAMESPACE}

# Check worker pods
kubectl get pods -l pipeline=${PIPELINE_NAME} -n ${NAMESPACE}

# Clean up (automatic after ttlSecondsAfterFinished)
# Or manual cleanup:
# kubectl delete job ${PIPELINE_NAME}-${TIMESTAMP} -n ${NAMESPACE}
```

---

## Use Case 3: GPU-based Deep Learning (Transformer Training)

### Motivation

Training transformer models on spatial omics data requires:

- Access to GPU resources
- Persistent model checkpoints and datasets
- Monitoring and logging capabilities
- Jupyter notebook interface for experimentation

### Architecture

```
Jupyter Lab → StatefulSet → GPU Node
     ↓              ↓
TensorBoard    Persistent Storage
```

### Deployment Template

```yaml
# gpu-ml-workspace.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${USERNAME}-ml-workspace
  namespace: ${NAMESPACE}
  labels:
    app: ml-workspace
    user: ${USERNAME}
spec:
  serviceName: ${USERNAME}-ml-workspace-service
  replicas: 1
  selector:
    matchLabels:
      app: ml-workspace
      user: ${USERNAME}
  template:
    metadata:
      labels:
        app: ml-workspace
        user: ${USERNAME}
    spec:
      nodeSelector:
        node-type: gpu-enabled
      containers:
        - name: ml-workspace
          image: tensorflow/tensorflow:latest-gpu-jupyter
          ports:
            - containerPort: 8888
              name: jupyter
            - containerPort: 6006
              name: tensorboard
          env:
            - name: JUPYTER_ENABLE_LAB
              value: "yes"
            - name: JUPYTER_TOKEN
              value: ${JUPYTER_TOKEN}
            - name: NVIDIA_VISIBLE_DEVICES
              value: "all"
            - name: NVIDIA_DRIVER_CAPABILITIES
              value: "compute,utility"
          resources:
            requests:
              memory: "16Gi"
              cpu: "4"
              nvidia.com/gpu: 1
            limits:
              memory: "32Gi"
              cpu: "8"
              nvidia.com/gpu: 1
          volumeMounts:
            - name: workspace
              mountPath: /tf/workspace
            - name: datasets
              mountPath: /tf/datasets
              readOnly: true
            - name: models-cache
              mountPath: /root/.cache
            - name: model-outputs
              mountPath: /tf/models
          command: ["/bin/bash"]
          args:
            - -c
            - |
              # Install additional packages
              pip install transformers datasets tensorboard wandb scanpy

              # Start TensorBoard in background
              tensorboard --logdir=/tf/models/logs --host=0.0.0.0 --port=6006 &

              # Start Jupyter
              jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
                --notebook-dir=/tf/workspace \
                --NotebookApp.token=${JUPYTER_TOKEN}
      volumes:
        - name: datasets
          nfs:
            server: ${NFS_SERVER}
            path: /shared/datasets/spatial-omics
        - name: models-cache
          emptyDir:
            sizeLimit: 10Gi
  volumeClaimTemplates:
    - metadata:
        name: workspace
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: ${STORAGE_CLASS}
        resources:
          requests:
            storage: 100Gi
    - metadata:
        name: model-outputs
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: ${STORAGE_CLASS}
        resources:
          requests:
            storage: 200Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ${USERNAME}-ml-workspace-service
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ml-workspace
    user: ${USERNAME}
  ports:
    - name: jupyter
      port: 8888
      targetPort: 8888
    - name: tensorboard
      port: 6006
      targetPort: 6006
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${USERNAME}-ml-workspace-ingress
  namespace: ${NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
spec:
  tls:
    - hosts:
        - ${USERNAME}-ml.${CLUSTER_DOMAIN}
        - ${USERNAME}-tensorboard.${CLUSTER_DOMAIN}
      secretName: ${TLS_SECRET_NAME}
  rules:
    - host: ${USERNAME}-ml.${CLUSTER_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${USERNAME}-ml-workspace-service
                port:
                  number: 8888
    - host: ${USERNAME}-tensorboard.${CLUSTER_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${USERNAME}-ml-workspace-service
                port:
                  number: 6006
```

### Training Script Template

```python
# spatial_transformer_training.py
import tensorflow as tf
from transformers import TFAutoModel, AutoTokenizer
import scanpy as sc
import pandas as pd
import numpy as np
from datetime import datetime
import os

class SpatialTransformerTrainer:
    def __init__(self, model_name="microsoft/DialoGPT-medium", output_dir="/tf/models"):
        self.model_name = model_name
        self.output_dir = output_dir
        self.setup_logging()

    def setup_logging(self):
        """Setup TensorBoard logging"""
        log_dir = os.path.join(self.output_dir, "logs", datetime.now().strftime("%Y%m%d-%H%M%S"))
        self.tensorboard_callback = tf.keras.callbacks.TensorBoard(
            log_dir=log_dir,
            histogram_freq=1,
            update_freq='epoch'
        )

    def load_spatial_data(self, data_path="/tf/datasets"):
        """Load and preprocess spatial omics data"""
        # Your spatial omics data loading logic here
        print(f"Loading spatial omics data from {data_path}")
        # This is a placeholder - replace with your actual data loading
        return None

    def prepare_model(self):
        """Initialize and compile the transformer model"""
        strategy = tf.distribute.MirroredStrategy()

        with strategy.scope():
            model = TFAutoModel.from_pretrained(self.model_name)
            # Add your custom layers for spatial omics analysis
            # model = self.add_spatial_layers(model)

            model.compile(
                optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
                loss='mse',  # Adjust based on your task
                metrics=['mae']
            )

        return model

    def train(self, epochs=100, batch_size=32):
        """Train the model"""
        # Load data
        data = self.load_spatial_data()

        # Prepare model
        model = self.prepare_model()

        # Setup callbacks
        callbacks = [
            self.tensorboard_callback,
            tf.keras.callbacks.ModelCheckpoint(
                filepath=os.path.join(self.output_dir, "checkpoints", "model_{epoch:02d}.h5"),
                save_best_only=True,
                monitor='val_loss'
            ),
            tf.keras.callbacks.EarlyStopping(
                patience=10,
                restore_best_weights=True
            )
        ]

        # Train model
        print("Starting training...")
        # history = model.fit(
        #     train_dataset,
        #     validation_data=val_dataset,
        #     epochs=epochs,
        #     callbacks=callbacks
        # )

        # Save final model
        model.save(os.path.join(self.output_dir, "final_model"))
        print(f"Model saved to {self.output_dir}/final_model")

if __name__ == "__main__":
    trainer = SpatialTransformerTrainer()
    trainer.train()
```

### Deployment Commands

```bash
# Set environment variables for GPU workspace
export USERNAME="your-username"
export NAMESPACE="your-namespace"
export JUPYTER_TOKEN=$(openssl rand -hex 32)
export CLUSTER_DOMAIN="your-cluster-domain.com"
export STORAGE_CLASS="fast-ssd"  # Use fast storage for ML workloads
export NFS_SERVER="your-nfs-server-ip"
export TLS_SECRET_NAME="your-tls-secret"

# Deploy ML workspace
envsubst < gpu-ml-workspace.yaml | kubectl apply -f -

# Check GPU allocation
kubectl describe pod -l app=ml-workspace -n ${NAMESPACE}

# Monitor resource usage
kubectl top pod -l app=ml-workspace -n ${NAMESPACE}

# Access URLs
echo "Jupyter Lab: https://${USERNAME}-ml.${CLUSTER_DOMAIN}"
echo "TensorBoard: https://${USERNAME}-tensorboard.${CLUSTER_DOMAIN}"
echo "Token: ${JUPYTER_TOKEN}"

# Clean up when done
envsubst < gpu-ml-workspace.yaml | kubectl delete -f -
```

---

## Environment Variables Template

### .env.example

```bash
# Cluster Configuration
CLUSTER_DOMAIN="your-cluster-domain.com"
NFS_SERVER="your-nfs-server-ip"
STORAGE_CLASS="your-default-storage-class"
TLS_SECRET_NAME="your-tls-secret"

# User Configuration
USERNAME="your-username"
NAMESPACE="your-namespace"
PROJECT_NAME="your-project"

# Security
JUPYTER_TOKEN=""  # Will be generated automatically

# Data Paths
INPUT_NFS_PATH="/shared/projects/your-project/input"
OUTPUT_NFS_PATH="/shared/projects/your-project/output"

# Pipeline Specific
PIPELINE_NAME="your-pipeline"
PIPELINE_REPO="your-pipeline-repo"
PIPELINE_REVISION="main"
PIPELINE_PARAMS=""

# Timestamps (generated automatically)
TIMESTAMP=""
```

---

## Best Practices and Tips

### Resource Management

1. **Always set resource requests and limits** to ensure fair sharing
2. **Use appropriate node selectors** for CPU vs GPU workloads
3. **Clean up resources** when jobs are complete
4. **Monitor resource usage** with `kubectl top`

### Storage Best Practices

1. **Use appropriate storage classes** - fast SSD for databases/ML, standard for archives
2. **Size your PVCs appropriately** - consider intermediate files and growth
3. **Use ReadOnlyMany** for shared reference data
4. **Clean up unused PVCs** to free storage space
5. **Use emptyDir for temporary data** that doesn't need persistence

### Security Considerations

1. **Never store secrets in YAML files** - use Kubernetes secrets or external secret management
2. **Use least-privilege RBAC** - only grant necessary permissions
3. **Keep container images updated** and scan for vulnerabilities
4. **Use network policies** to restrict pod-to-pod communication if needed
5. **Rotate access tokens regularly**

### Monitoring and Debugging

#### Common kubectl Commands for Troubleshooting

```bash
# Check pod status and events
kubectl get pods -n ${NAMESPACE}
kubectl describe pod <pod-name> -n ${NAMESPACE}

# View logs
kubectl logs <pod-name> -n ${NAMESPACE}
kubectl logs <pod-name> -n ${NAMESPACE} --previous  # Previous container instance

# Check resource usage
kubectl top pods -n ${NAMESPACE}
kubectl top nodes

# Debug networking
kubectl get services -n ${NAMESPACE}
kubectl get ingress -n ${NAMESPACE}

# Check persistent volumes
kubectl get pv
kubectl get pvc -n ${NAMESPACE}

# Event monitoring
kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp'
```

#### Common Issues and Solutions

**Pod stuck in Pending state:**

- Check resource requests vs available cluster resources
- Verify node selectors match available nodes
- Check PVC binding status

**Out of Memory/CPU:**

- Increase resource limits
- Check for memory leaks in applications
- Consider using multiple smaller pods instead of one large pod

**Storage Issues:**

- Verify PVC is bound
- Check available storage in the cluster
- Ensure correct storage class is specified

**Network/Ingress Issues:**

- Verify service selectors match pod labels
- Check ingress annotations and rules
- Confirm DNS resolution and SSL certificates

---

## Quick Reference Commands

### Deployment Commands

```bash
# Source environment variables
source .env

# Deploy Jupyter Notebook
envsubst < templates/jupyter-notebook.yaml | kubectl apply -f -

# Deploy Nextflow Pipeline
export TIMESTAMP=$(date +%Y%m%d-%H%M%S)
envsubst < templates/nextflow-pipeline.yaml | kubectl apply -f -

# Deploy ML Workspace
envsubst < templates/gpu-ml-workspace.yaml | kubectl apply -f -

# Monitor deployments
kubectl get all -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
kubectl get ingress -n ${NAMESPACE}
```

### Cleanup Commands

```bash
# Clean up specific deployments
kubectl delete statefulset ${USERNAME}-jupyter -n ${NAMESPACE}
kubectl delete job ${PIPELINE_NAME}-${TIMESTAMP} -n ${NAMESPACE}
kubectl delete statefulset ${USERNAME}-ml-workspace -n ${NAMESPACE}

# Clean up all resources for a user
kubectl delete all -l user=${USERNAME} -n ${NAMESPACE}

# Clean up PVCs (be careful!)
kubectl delete pvc -l user=${USERNAME} -n ${NAMESPACE}
```

### Monitoring Commands

```bash
# Real-time pod monitoring
watch kubectl get pods -n ${NAMESPACE}

# Resource usage monitoring
watch kubectl top pods -n ${NAMESPACE}

# Log following
kubectl logs -f <pod-name> -n ${NAMESPACE}

# Port forwarding for local access
kubectl port-forward pod/<pod-name> 8888:8888 -n ${NAMESPACE}
```

---

## Troubleshooting Guide

### Common Scenarios

#### Scenario 1: Jupyter Notebook Won't Start

**Symptoms:**

- Pod is running but can't access the web interface
- Getting connection refused errors

**Diagnosis:**

```bash
kubectl describe pod <jupyter-pod-name> -n ${NAMESPACE}
kubectl logs <jupyter-pod-name> -n ${NAMESPACE}
kubectl get ingress -n ${NAMESPACE}
```

**Common Solutions:**

1. Check if the JUPYTER_TOKEN is correctly set
2. Verify ingress configuration and DNS resolution
3. Ensure the service selector matches pod labels
4. Check for resource constraints

#### Scenario 2: Nextflow Job Fails

**Symptoms:**

- Job completes with error status
- Worker pods fail to start

**Diagnosis:**

```bash
kubectl logs job/${PIPELINE_NAME}-${TIMESTAMP} -n ${NAMESPACE}
kubectl get pods -l pipeline=${PIPELINE_NAME} -n ${NAMESPACE}
kubectl describe pod <failed-pod-name> -n ${NAMESPACE}
```

**Common Solutions:**

1. Check RBAC permissions for the service account
2. Verify input/output paths are accessible
3. Ensure container images are available
4. Check resource requests vs cluster availability

#### Scenario 3: GPU Not Available

**Symptoms:**

- Pod stuck in pending state
- "Insufficient nvidia.com/gpu" error

**Diagnosis:**

```bash
kubectl describe nodes -l node-type=gpu-enabled
kubectl get pods -n ${NAMESPACE} -o wide
kubectl describe pod <pending-pod-name> -n ${NAMESPACE}
```

**Common Solutions:**

1. Check if GPU nodes are available and schedulable
2. Reduce GPU resource requests
3. Check if other users are using all GPUs
4. Verify node selector is correct

---

## Advanced Topics

### Custom Resource Definitions (CRDs)

Some bioinformatics tools provide their own Kubernetes operators:

```bash
# Example: Argo Workflows for complex pipelines
kubectl get workflows -n ${NAMESPACE}
kubectl describe workflow <workflow-name> -n ${NAMESPACE}
```

### Horizontal Pod Autoscaling

For variable workloads, you can enable automatic scaling:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nextflow-hpa
  namespace: ${NAMESPACE}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nextflow-workers
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### Job Queues with Volcano

For better batch job scheduling:

```yaml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: bioinf-batch-job
spec:
  schedulerName: volcano
  queue: bioinformatics-queue
  tasks:
    - replicas: 4
      name: worker
      template:
        spec:
          containers:
            - name: worker
              image: bioinformatics/pipeline:latest
```

---

## Useful Links and Resources

### Documentation

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Nextflow on Kubernetes](https://www.nextflow.io/docs/latest/kubernetes.html)

### Bioinformatics-Specific Resources

- [nf-core Pipelines](https://nf-co.re/)
- [Galaxy on Kubernetes](https://galaxyproject.org/cloud/k8s/)
- [Bioconda Containers](https://biocontainers.pro/)

### Monitoring and Observability

- [Prometheus for Kubernetes](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

---

## Workshop Exercises

### Exercise 1: Deploy Your First Jupyter Notebook

1. Set up your `.env` file with your personal configuration
2. Deploy a Jupyter notebook using the provided template
3. Access the notebook through the web interface
4. Create a simple Python script to test data access
5. Save your work and verify persistence after pod restart

### Exercise 2: Run a Simple Nextflow Pipeline

1. Fork or clone a simple nf-core pipeline
2. Modify the pipeline parameters for your dataset
3. Deploy the pipeline using the Kubernetes executor
4. Monitor the pipeline execution and worker pods
5. Examine the results and logs

### Exercise 3: Set Up ML Training Environment

1. Deploy the GPU-enabled ML workspace
2. Install additional Python packages for your specific use case
3. Load a sample spatial omics dataset
4. Set up a simple training loop with TensorBoard logging
5. Monitor GPU utilization and training progress

### Exercise 4: Data Management

1. Create different types of persistent volumes for your workflows
2. Practice mounting shared datasets and reference genomes
3. Set up proper backup and cleanup procedures
4. Test data persistence across pod restarts

### Exercise 5: Troubleshooting

1. Intentionally create common misconfigurations
2. Practice using kubectl commands to diagnose issues
3. Fix the problems using the troubleshooting guide
4. Document your solutions for future reference

---

## Conclusion

This workshop has provided you with:

- **Fundamental understanding** of Kubernetes concepts
- **Practical templates** for common bioinformatics workloads
- **Best practices** for resource management and security
- **Troubleshooting skills** for common issues
- **Scalable solutions** that can grow with your research needs

### Next Steps

1. **Start small**: Begin with simple Jupyter notebooks and gradually move to more complex workflows
2. **Monitor resources**: Always keep an eye on cluster resource usage
3. **Collaborate**: Share templates and best practices with your team
4. **Stay updated**: Kubernetes and bioinformatics tools evolve rapidly
5. **Contribute back**: Share your improvements and custom templates with the community

### Getting Help

- **Cluster administrators**: For resource allocation and access issues
- **Bioinformatics team**: For pipeline-specific questions
- **Kubernetes community**: For general Kubernetes questions
- **Documentation**: Always refer to official documentation first

Remember: Kubernetes is a powerful tool, but with great power comes great responsibility. Always be mindful of resource usage and clean up after your jobs to ensure fair access for all users.

Happy computing! 🧬🚀
