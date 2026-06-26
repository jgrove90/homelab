Open /mnt/apps/home-assistant/configuration.yaml on your NFS server (or wherever your Home Assistant config is stored).

Add:

http:  use_x_forwarded_for: true  trusted_proxies:    - 10.244.0.0/16
Save the file.
Restart the Home Assistant pod:

kubectl -n home-assistant delete pod <pod-name>
