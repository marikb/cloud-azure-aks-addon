# cloud-azure-aks-addon

Provision a **new** AKS cluster with the **Azure Policy add-on** (plus managed
Azure AD integration, autoscaling, automatic upgrades, and Container Insights
monitoring) using Terraform (`terraform/`); govern **all current and future**
clusters at scale via a management-group DeployIfNotExists policy (`governance/`);
and optionally backfill the add-on on existing clusters with a one-time PowerShell
script (`scripts/`).

Azure Policy makes it possible to apply at-scale enforcements and safeguards on
your clusters, and to manage and report on their compliance state from one place.
For full documentation see the
[Azure Policy for Kubernetes overview](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#overview).

## Repository layout

| Path | What it does |
| --- | --- |
| `terraform/` | Terraform config that provisions a **new** AKS cluster with the Azure Policy add-on, managed Azure AD RBAC, autoscaling, automatic upgrades, and Log Analytics monitoring. |
| `governance/` | Terraform config that assigns a management-group **DeployIfNotExists** policy so **all current and future** AKS clusters get the Azure Policy add-on automatically. This is the recommended at-scale mechanism. |
| `scripts/Enable-AksPolicyAddon.ps1` | Optional **one-time backfill**: enables the add-on on existing AKS clusters across every subscription your account can access. |
| `*/tests/` | Native `terraform test` suites (run with no Azure credentials via `mock_provider`). |
| `CHANGELOG.md` | History of notable changes. |

## Prerequisites

- An Azure subscription and permission to create resource groups, AKS clusters,
  and Azure AD groups.
- Signed in with the Azure CLI (`az login`) — or run from
  [Azure Cloud Shell](https://shell.azure.com), which is already authenticated.
- [Terraform](https://developer.hashicorp.com/terraform/downloads) **>= 1.7.0**
  (preinstalled in Cloud Shell) for the Terraform workflow.
- For `governance/` only: **Owner** (or Resource Policy Contributor + User Access
  Administrator) on the target management group, since it creates policy and role
  assignments at that scope.
- For host encryption (on by default), register the feature once per subscription
  before `apply`: `az feature register --namespace Microsoft.Compute --name EncryptionAtHost`
  (then `az provider register --namespace Microsoft.Compute`). Set
  `host_encryption_enabled = false` to skip.

## Provision a cluster with Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # optional: customize inputs
terraform init
terraform plan
terraform apply
```

After apply, connect with the command shown in the `get_credentials_command`
output:

```bash
az aks get-credentials --resource-group <rg> --name <cluster>
```

All inputs are optional and documented in
[`terraform/variables.tf`](terraform/variables.tf); see
[`terraform/terraform.tfvars.example`](terraform/terraform.tfvars.example) for the
defaults.

### Run the tests

The tests use `mock_provider`, so they need **no Azure credentials** and create
nothing:

```bash
cd terraform
terraform init
terraform test
```

### Security defaults

The cluster ships hardened: local admin accounts disabled (all access via Entra),
Workload Identity + OIDC issuer on, Image Cleaner on, host encryption on the nodes,
the Key Vault Secrets Provider (CSI) for mounting secrets, and **Azure CNI Overlay
with Cilium network policy** so `NetworkPolicy` objects are actually enforced. Two
knobs need your attention:

- `api_server_authorized_ip_ranges` — empty by default (API server is public). To
  lock it down, set your client egress CIDRs (**including Cloud Shell's**) or you
  will lock yourself out.
- The `network_profile` is **ForceNew** — changing the plugin/policy/CIDRs after
  creation recreates the cluster, so decide at provisioning time.

## Govern all clusters at scale with a policy (recommended)

The `governance/` module assigns the built-in **"Deploy Azure Policy Add-on to
Azure Kubernetes Service clusters"** DeployIfNotExists policy at a management
group. Every current and future AKS cluster in that hierarchy then gets the add-on
installed automatically, with compliance reporting — no per-cluster scripting.

```bash
cd governance
cp terraform.tfvars.example terraform.tfvars   # set management_group_name
terraform init
terraform test    # optional: 3 tests, no credentials needed
terraform apply
```

You must run it as **Owner** (or Resource Policy Contributor + User Access
Administrator) on that management group, because it creates a policy assignment
**and** role assignments there. The module grants the assignment's managed
identity the two roles the policy requires (*Azure Kubernetes Service Contributor
Role* and *Azure Kubernetes Service Policy Add-on Deployment*).

**On backfilling existing clusters:** by default the module also creates a
remediation task, but the first run may remediate **zero** clusters — a fresh
assignment has no compliance data until the initial management-group scan finishes
(~30 minutes), and RBAC can take a few minutes to propagate (an early run may
report `AuthorizationFailed`). The remediation task is create-only, so a plain
`terraform apply` won't re-run it; re-trigger it explicitly once things settle:

```bash
terraform apply -replace=azurerm_management_group_policy_remediation.aks_policy_addon[0]
```

For an *immediate* backfill instead of waiting, run the one-time script below.

Beyond installing the add-on, the module also assigns a built-in **pod security
baseline** initiative in **Audit** mode by default (set `baseline_effect = "Deny"`
to block non-compliant workloads, or `assign_security_baseline = false` to skip) —
so it enforces guardrails, not just installs the add-on.

This is complementary to the cluster module: `terraform/` enables the add-on
immediately on clusters it creates, and the policy is the safety net for
everything else.

## One-time backfill on existing clusters (optional)

If you want the add-on enabled on existing clusters right now (rather than waiting
for the policy remediation), the script iterates every enabled subscription your
account can access (across all tenants, via `az account list --all`) and enables
the add-on on each cluster. Run it in Azure Cloud Shell (PowerShell):

```powershell
./scripts/Enable-AksPolicyAddon.ps1
```

The Azure Policy add-on for AKS is Generally Available, so no preview extension or
feature registration is required — only the `Microsoft.PolicyInsights` provider,
which the script registers automatically. For ongoing governance, prefer the
`governance/` policy above over re-running this script.

## Remote state (optional)

State is local by default. To use Azure Blob state with locking, rename
`backend.tf.example` to `backend.tf` in each module, bootstrap a storage account
out-of-band, and `terraform init`. Use a **distinct state key per module**.

## Continuous integration

[.github/workflows/terraform.yml](.github/workflows/terraform.yml) runs
`fmt` / `validate` / `terraform test` on both modules for every PR — no cloud
credentials, since the tests use `mock_provider`. It's included in the repo, but
committing workflow files requires a `gh` token with `workflow` scope.

## Additional resources

- [Install Azure Policy add-on for AKS](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks)
- [AKS auto-upgrade](https://learn.microsoft.com/en-us/azure/aks/auto-upgrade-cluster)
- [Kured (reboot daemon)](https://learn.microsoft.com/en-us/azure/aks/upgrade-node-image-kured)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the history of changes.
