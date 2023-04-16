echo "--------------Script to create a master-------------"
sleep 3

# Disable SELinux
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Enable br_netfilter kernel module
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
touch /etc/sysctl.d/k8s.conf
echo 'net.bridge.bridge-nf-call-ip6tables = 1' > /etc/sysctl.d/k8s.conf
echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.d/k8s.conf
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p
# Disable Swap 
swapoff -a
sed -i '/swap/d' /etc/fstab

# Install Docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io

# Add kubernetes repository
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Install kubectl, kubelet and kubeadm
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Start and enable docker service
systemctl start --now docker
systemctl enable --now docker

# Start and enable kubelet service
systemctl start --now kubelet
systemctl enable --now kubelet

echo "----------Installation on master completed successfully------------"

# Get worker IP
echo "Please enter the worker IP:"
read -r ip

# Copy worker-kube.sh to worker node
scp /root/worker.sh root@"$ip":/root/

# Execute worker-kube.sh on worker node
ssh root@"$ip" "bash /root/worker.sh"

sleep 15s

# Add firewall rules
echo "Adding Firewall Rules"
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp
firewall-cmd --reload

sleep 3s

rm -rf /etc/containerd/config.toml
systemctl restart containerd


# Initialize Kubernetes cluster and generate join token
echo "Creating Token for worker node"
kubeadm init --pod-network-cidr 10.244.0.0/16 --apiserver-advertise-address=192.168.1.10

sleep 10s

# Save join token to file
kubeadm token create --print-join-command > /root/join-token

touch /root/join-token
chmod +x /root/join-token
nano /root/join-token
sleep 15s
scp /root/join-token $ip:/root/
sleep 5s
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/techarkit/Linux_guides/master/kube-flannel.yml
ssh root@$ip "/root/join-token" > /root/join-token
sleep 180s
echo "####### Clustering is DONE!!!! ######"
kubectl get pods --all-namespaces
kubectl get nodes
sleep 5s

echo "####### Cluster hardening ######"
bash hardening.sh

echo "#*#*#*#*#* Cluster Hardening Completed *#*#*#*#*#"
