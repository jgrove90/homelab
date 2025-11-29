Initial Install 

Initialize flux 
flux bootstrap github \
  --owner=your-github-username \
  --repository=your-repo-name \
  --branch=main \
  --path=clusters/homelab
1. kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

add sops secret
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=$HOME/.sops/age/keys.txt

add secrets to k8's
2. sops-decrypt config-secret.enc.yaml | kubectl apply -f - 


assiging a new mac address 
 printf 'bc:24:11:%02x:%02x:%02x\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))