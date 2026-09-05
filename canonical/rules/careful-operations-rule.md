# Careful Operations — Destructive Command Guardrails

Three-tier classification of destructive operations: Blocked / Requires Confirmation / Exceptions.

## Precedence

1. **Hook denies → obey.** Hooks mechanically block §1 patterns. Do not seek workarounds.
2. **Hook passes + §2 match → ask user.** Context (prod/dev/target) matters. Present the command and blast radius, then stop.
3. **§3 exception applies → allow** even if the pattern matches §1. Hooks recognize the same exceptions.

In environments without hooks, apply the blocked-pattern list as agent-side blocks (same as §2). Read that list from `canonical/hooks/README.md` before relying on this rule alone — §1 below is a summary, not the enumeration. The principles of this rule are independent of hook availability.

Concretizes `behavioral-rule.md` §3 "Safe Operations." §2 patterns are the primary application. §1 is enforced by hooks.

## 1. Blocked (hook-enforced)

Hooks mechanically block a fixed set of destructive commands. The families: recursive force-deletes aimed at root, home, `.`, `..`, or any absolute path outside the safe directories of §3; recursive permission and owner changes under root; filesystem creation; direct device writes; bare force-push; hard reset; `git clean -fdx`; and SQL `DROP` / `TRUNCATE`. The command is denied.

**The list of blocked patterns lives with the hooks, not here** — see the `block-destructive.sh` and `block-force-push.sh` sections of `canonical/hooks/README.md`. Keeping one copy next to the scripts is what makes the two agree; a second copy in an always-loaded rule drifts silently.

## 2. Requires Confirmation (not hook-decidable — rule-enforced)

Context-dependent — hooks cannot decide these. Stop before executing. Present the command and blast radius.

### Containers / Clusters

| Pattern | Risk | Confirm |
|---------|------|---------|
| `kubectl delete` | Deletes Pods, Deployments, Namespaces | Target resource, namespace, prod vs dev |
| `docker system prune` | Bulk removal of unused images/containers/volumes | `--volumes` flag, shared environment |
| `docker rm -f` / `docker stop` | Force-stops running containers | Dependent processes |

### Infrastructure / Cloud

| Pattern | Risk | Confirm |
|---------|------|---------|
| `terraform destroy` | Destroys infra resources | Plan reviewed, target environment |
| `aws s3 rm --recursive` | Bulk S3 deletion | Bucket name, production data |
| `gcloud ... delete` | GCP resource deletion | Project ID, resource type |

### Packages / Dependencies

| Pattern | Risk | Confirm |
|---------|------|---------|
| `npm publish` / `gem push` | Public release (hard to retract) | Version, target registry |
| Major version downgrade | Breaking change risk | Downstream impact |

### Git (not hooked)

| Pattern | Risk | Confirm |
|---------|------|---------|
| `git rebase` (public branch) | Rewrites shared history | Whether others share the branch |
| `git branch -D` | Force-deletes unmerged branch | Merge status, remaining work |
| `git checkout -- .` / `git restore .` | Discards all uncommitted changes | Whether to `git stash` first |

## 3. Exceptions (blocked patterns that are safe)

### Safe directories for rm -rf

Build artifacts and caches are allowed as `rm -rf` targets. The list is `SAFE_DIRS_RE` in `block-destructive.sh`, documented in the same section of `canonical/hooks/README.md`. Do not restate it here.

### Safe Git alternatives

| Blocked pattern | Safe alternative |
|-----------------|-----------------|
| `git push --force` | `git push --force-with-lease` (prevents unintended remote overwrite) |
| `git reset --hard` | `git stash` → `git stash drop` if needed |
| `git clean -fdx` | `git clean -fd` (no `-x`: preserves .gitignore targets) |

### sudo handling

Hooks strip `sudo` before pattern matching. `sudo rm -rf /` is still blocked.
