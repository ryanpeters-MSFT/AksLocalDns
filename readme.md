# AKS LocalDNS (Managed)

AKS LocalDNS runs a DNS proxy and cache as a systemd service (`localdns.service`) on each node. It reduces query latency and conntrack pressure, forwards Kubernetes service queries to CoreDNS, and supports caching, stale responses, logging, and forwarding controls.

AKS Automatic includes LocalDNS preconfigured. This repository demonstrates explicit LocalDNS configuration on AKS Standard node pools. Starting with Kubernetes 1.37, eligible AKS Standard node pools without an explicit profile default to `Preferred` mode and can enable LocalDNS after compatibility checks.

## Prerequisites

- Azure CLI 2.80.0 or later. The `aks-preview` extension and `LocalDNSPreview` feature registration are no longer required.
- Kubernetes 1.31 or later.
- Azure Linux or Ubuntu 22.04 and later node images.
- A node VM SKU with at least 4 vCPUs.
- If the VNet uses custom DNS servers, both UDP and TCP port 53 must work from the AKS node subnet. Test both transports before enabling LocalDNS.
- Do not run upstream Kubernetes NodeLocal DNSCache on the same node pool.

Updating a LocalDNS profile on an existing node pool reimages every node in that pool. Plan for temporary node unavailability and use workload replicas and pod disruption budgets for production rollouts.

## Quickstart

Invoke [setup.ps1](./setup.ps1) to create an AKS Standard cluster and enable LocalDNS on the system pool and a new user pool. The script uses 4-vCPU Ubuntu 22.04 nodes and applies the Microsoft-documented default configuration from [dnsconfig.json](./dnsconfig.json) in `Required` mode. It isn't intended to update an existing deployment.

```powershell
# invoke setup
.\setup.ps1
```

`Required` mode fails the node-pool operation if LocalDNS prerequisites aren't met. Microsoft recommends first validating custom configurations with `Preferred` mode before changing them to `Required`. On Kubernetes 1.31 through 1.36, `Preferred` validates the configuration without enabling LocalDNS; on 1.37 and later, it enables LocalDNS only after compatibility checks pass. Applying either mode to an existing pool can trigger a reimage.

## Verification

Once configured, verify that queries from pods use the LocalDNS instance on link-local IP `169.254.10.10` or `169.254.10.11`.

```powershell
# test resolution and forwarding to coredns
kubectl run netshoot --image=nicolaka/netshoot -it --rm --restart=Never -- nslookup metrics-server.kube-system.svc.cluster.local
```

The `Server` field should contain one of the LocalDNS link-local IPs, and the service name should resolve to its cluster IP.

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

### CoreDNS Forwarding Verification

To verify that LocalDNS forwards `cluster.local` requests to CoreDNS:

1. Edit the `coredns-custom` config map to output log entries to the console.

    ```yaml
    data:
      logs.override: |
        log
    ```

2. Restart the CoreDNS pods. 

    ```powershell
    kubectl rollout restart deploy coredns -n kube-system
    ```

3. Open a second console window and output the logs from CoreDNS.

    ```powershell
    # view live logs for coredns
    kubectl logs -l k8s-app=kube-dns -n kube-system -f
    ```

4. Run the `nslookup` command again and observe that CoreDNS handles the `metrics-server.kube-system.svc.cluster.local` request.

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

## References

- [DNS Resolution in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/dns-concepts)
- [Configure LocalDNS in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/localdns-custom)
- [Azure CLI `az aks nodepool` reference](https://learn.microsoft.com/cli/azure/aks/nodepool)
- [Accelerate DNS Performance with LocalDNS](https://blog.aks.azure.com/2025/08/04/accelerate-dns-performance-with-localdns)