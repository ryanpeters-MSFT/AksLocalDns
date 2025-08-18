# AKS LocalDNS (Managed)

AKS LocalDNS is a feature that deploys a DNS proxy and cache as a systemd service (`localdns.service`) on each cluster node, enabling distributed resolution of queries from pods to reduce network hops and improve performance. It integrates with CoreDNS for internal cluster domains and VNet DNS for external ones, offering customizable caching, forwarding policies, and protocol controls like forcing TCP to enhance reliability. This addresses common issues in large or high-traffic clusters, such as DNS latency, conntrack table exhaustion, uneven load on centralized CoreDNS pods, and resolution failures during upstream outages, resulting in up to 10x faster queries and better scalability.

## Quickstart

Update the preview extension and add the flag:

```powershell
az extension update --name aks-preview
az feature register --namespace "Microsoft.ContainerService" --name "LocalDNSPreview"
az provider register --namespace Microsoft.ContainerService
```

Invoke [setup.ps1](./setup.ps1) to create the cluster and enable LocalDNS on both the system and a new user node pool. The script will apply a default `--localdns-config` configuration file in [dnsconfig.json](./dnsconfig.json). You may adjust this as needed.

```powershell
# invoke setup
.\setup.ps1
```

## Verification

Once configured, verify that queries from pods are resolving using the LocalDNS instance running on the link-local IP 169.254.10.10 or 169.254.10.11. 

```powershell
# test resolution and forwarding to coredns
kubectl run netshoot --image=nicolaka/netshoot -it --rm --restart=Never -- nslookup metrics-server.kube-system.svc.cluster.local
```

The output from the last command should indicate that the DNS request was handled by the link-local DNS IP and the `metrics-server.kube-system` domain has resolved to the correct service IP. 

```powershell
;; Got recursion not available from 169.254.10.11
;; Got recursion not available from 169.254.10.11
Server:         169.254.10.11
Address:        169.254.10.11#53

Name:   metrics-server.kube-system.svc.cluster.local
Address: 10.0.129.12
;; Got recursion not available from 169.254.10.11

pod "netshoot" deleted
```

### Upstream DNS Verification

In addition, you should also verify that CoreDNS has handled the forwarded request from the Local DNS.

1. Edit the `coredns-custom` config map to output log entries to the console.

    ```yaml
    # added to coredns-custom
    data:
    logs.override: |
        log
    ```

2. Restart the CoreDNS pods. 

    ```powershell
    kubectl rollout restart deploy coredns -n kube-system
    ```

3. Open a second console window and output the logs from CoreDNS.

    ````powershell
    # view live logs for coredns
    kubectl logs -l k8s-app=kube-dns -n kube-system -f
    ````

4. Invoke the `nslookup` command from above and observe that the request to "metrics-server.kube-system.svc.cluster.local" are handled by CoreDNS.

    ```powershell
    # test resolution and forwarding to coredns
    kubectl run netshoot --image=nicolaka/netshoot -it --rm --restart=Never -- nslookup metrics-server.kube-system.svc.cluster.local
    ```

    Output:

    ```bash
    [INFO] 10.224.0.7:27417 - 16625 "A IN metrics-server.kube-system.svc.cluster.local. tcp 62 false 65535" NOERROR qr,aa,rd 122 0.000098102s
    [INFO] 10.224.0.7:27417 - 53172 "AAAA IN metrics-server.kube-system.svc.cluster.local. tcp 62 false 65535" NOERROR qr,aa,rd 155 0.000090502s
    ```

### LocalDNS Systemd Service Verification

In order to view the status of the `localdns.service`, or view logs from the service, run the following commands on the node (you may use `kubectl debug node/NODENAME -it --image=busybox -- chroot /host` to access the node).

```powershell
# view service status
systemctl status localdns.service

# view recent logs
journalctl -u localdns.service -n 100
```

## Links
- [DNS Resolution in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/dns-concepts#localdns-in-azure-kubernetes-service-preview)
- [Configure LocalDNS in Azure Kubernetes Service (Preview)](https://learn.microsoft.com/en-us/azure/aks/localdns-custom)
- [Accelerate DNS Performance with LocalDNS](https://blog.aks.azure.com/2025/08/04/accelerate-dns-performance-with-localdns)