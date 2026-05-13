# Share Test File

This is a proof-of-concept file to verify that GitHub Pages renders markdown correctly — including diagrams and images.

## Architecture Overview

```mermaid
graph TD
    A[Private Repo] -->|push| B[GitHub Action]
    B -->|copies file| C[bydynamics/shared-docs]
    C -->|auto-build| D[GitHub Pages]
    D -->|serves| E[Customer Browser]

    style A fill:#f9f,stroke:#333
    style D fill:#bbf,stroke:#333
    style E fill:#bfb,stroke:#333
```

## Process Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant PS as PowerShell
    participant API as GitHub API
    participant Pages as GitHub Pages
    participant Customer

    Dev->>PS: publish-to-pages -File "doc.md"
    PS->>API: PUT contents/doc.md
    API->>Pages: trigger rebuild
    Pages-->>Customer: https://bydynamics.github.io/shared-docs/doc
```

## Sample Image

![Placeholder Image](https://picsum.photos/800/400)

> This is a random image from Lorem Picsum to test image embedding on Pages.

## Conclusion

If you can see this page rendered with the Mermaid diagrams and the image above, the publish-to-pages pipeline is working correctly.
