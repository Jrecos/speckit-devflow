# DevFlow bundle

The Spec Kit bundle manifest and (eventually) its authored components.

## Author / build (bundle authors)

```bash
specify bundle validate --path .                 # structural + reference checks
specify bundle build    --path . --output ../dist/   # versioned .zip artifact
```

`validate` checks `bundle.yml` for well-formedness and resolves every component reference
against bundled, installed, and catalog components — it fails only if a reference is
definitively absent. (So it will fail until the planned components under `provides` are
authored.)

## Install (consumers)

```bash
specify bundle search devflow
specify bundle info    devflow
specify bundle install devflow      # idempotent, confined to the project root
```

Bundles resolve through a priority-ordered catalog stack (project > user > built-in). To
distribute, host the built artifact and add a catalog source
(`specify bundle catalog add`).

See [`bundle.yml`](bundle.yml) for the (draft) component set and the repo
[`README`](../README.md) for the design.
