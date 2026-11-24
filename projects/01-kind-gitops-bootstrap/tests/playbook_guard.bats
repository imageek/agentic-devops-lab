#!/usr/bin/env bats
# The bootstrap playbook must refuse any context but kind-lab. The context
# used here doesn't exist, so even a broken guard couldn't reach a real
# cluster. Needs ANSIBLE_COLLECTIONS_PATH, which `make test` sets.

setup() {
  load test_helper
}

@test "the playbook refuses a context other than kind-lab" {
  run ansible-playbook \
    -i "$PROJECT_DIR/ansible/inventory.yml" \
    "$PROJECT_DIR/ansible/bootstrap.yml" \
    -e kube_context=kind-does-not-exist
  ((status != 0))
  # Failing for any other reason (a syntax error, a missing collection) would
  # also be non-zero, so check it's the guard that stopped it.
  [[ "$output" == *"only runs against kind-lab"* ]]
}
