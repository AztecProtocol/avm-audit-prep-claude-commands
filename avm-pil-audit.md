---
name: avm-pil-audit
description: Workflow for auditing a PIL file.
allowed-tools: Bash, Read, Grep, Glob
---
# Overview
The **Aztec Virtual Machine (AVM)** executes public transactions and proves correct execution. The **PIL files** in the `barretenberg/cpp/pil` directory define **relations**: constraints on a trace that characterize valid execution. PIL is Polygon’s Polynomial Identity Language.
A trace is a matric of columns and rows where each cell is a Field number (BN254 scalar). The relations that are defined are applied to every row of a trace.
**IMPORTANT**: Arithmetic on the cells is done over the BN254 scalar field.
The objective of a PIL file is to precisely define the possible traces that characterize the semantics of a given function $F$.
# What to look for
There can be two kinds of security bugs
- **Soundness**: A malicious actor could fill in the trace in a way that the end result does NOT correspond to any valid execution of the function $F$. For example, the result might be wrong for the right inputs while validating all constrains. This means that the trace is under-constrained. The constrains do not correctly characterize the set of traces. The set of traces is too big/loose. You should try to choose values yourself (do not rely on our tracegen code) to try to get to a wrong result while satisfying the constraints. While the objective is to change the result, you are free to change any intermediate rows or values as well.
- **Completeness**: There are valid executions of $F$ which cannot be modeled with the given columns and constrains. This means that the system is over-constrained. You should try to find valid inputs for which no possible values in the cells reach the desired output. For completeness you can assume the trace is generated via our C++ tracegen code.
