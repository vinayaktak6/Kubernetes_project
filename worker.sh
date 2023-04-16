echo "--------------Script to create a worker----------------"
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
yum install containerd.io -y
rm -rf /etc/containerd/config.toml
systemctl restart containerd

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

echo "----------Installation on worker completed successfully----------"
                                                                                                         

