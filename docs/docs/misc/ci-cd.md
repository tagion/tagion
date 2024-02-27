# Systemic overview
The overall purpose is to deliver continuous value to our users by:
using the scientific method to learn as fast as possible - fail fast.
We do this by an automated CI/CD flow that always produces a deployment candidate, which we can choose to deploy at any time.
The quality is defined by the requirements to the systems expressed in tests.

# Systemic overview tests
![Systemic overview](/figs/system_overview.png)


# Deployment Pipeline
![Deployment Pipeline](/figs/deployment_pipeline.png)

# Deployment Infastructure
[servers](https://www.notion.so/decardcorp/CI-Infrastructure-e6f10802b67548148f2a970e10f14936)


# Sequential diagram over workflow
```mermaid
flowchart LR

subgraph "Event: workflow_dispatch, push (current branch)"
  style A fill:#f9f9f9,stroke:#cccccc,stroke-width:1px,stroke-dasharray: 5,5
  A[Main Flow]

  subgraph commit_stage
    style B fill:#f9f9f9,stroke:#cccccc,stroke-width:1px,stroke-dasharray: 5,5
    B[commit_stage]
    H["get repository"]
    I["pull"]
    J["Run tests"]
    K["Report unittests"]
    L["Report bddtests"]
    M["Add schedule to build"]
    N["Create tar ball"]
    O["Upload to shared directory"]
    P["Upload code coverage"]
    Q["Cleanup"]
  end

  subgraph acceptance_stage
    style C fill:#f9f9f9,stroke:#cccccc,stroke-width:1px,stroke-dasharray: 5,5
    C[acceptance_stage]
    Q["Copy Artifact to local machine"]
    R["Run collider tests"]
    S["Generate reports"]
    T["Create tar ball"]
    U["Upload to shared directory"]
    V["Cleanup"]
  end

  subgraph ddoc_build
    style E fill:#f9f9f9,stroke:#cccccc,stroke-width:1px,stroke-dasharray: 5,5
    E[ddoc_build]
    Z["Copy Artifact to local machine"]
    AA["Send ddoc to repository"]
    BB["clean up"]
  end

  subgraph docs_build
    style F fill:#f9f9f9,stroke:#cccccc,stroke-width:1px,stroke-dasharray: 5,5
    F[docs_build]
    CC["Checkout"]
    DD["Setup Pages"]
    EE["Upload artifact"]
    FF["Deploy to GitHub Pages"]
  end

  subgraph finish_workflow
    style G fill:#f9f9f9,stroke:#cccccc,stroke-width:1px,stroke-dasharray: 5,5
    G[finish_workflow]
    GG["Copy Artifact to local machine"]
    HH["Generate report"]
    II["Upload artifact"]
    JJ["Cleanup"]
  end

  A --> B
  B --> C
  C --> E
  C --> F
  E --> G
  F --> G
end
```
