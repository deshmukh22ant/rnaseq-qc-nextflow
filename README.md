# rnaseq-qc — A Containerized Nextflow QC Pipeline

A reproducible, containerized [Nextflow](https://www.nextflow.io/) pipeline that performs quality control on RNA-seq sequencing data: it trims raw reads, checks their quality, and aggregates the results into a single report. Built as the scientific-workflow layer of a larger discovery data platform.

> **Status:** Working locally on real sequencing data. Cloud execution (Seqera Platform / AWS Batch) and a downstream Databricks lakehouse are the planned next phases — see [Roadmap](#roadmap).

---

## The problem this solves

Before any genomic analysis can be trusted, the raw sequencing data has to be **quality-checked and cleaned** — and this has to happen consistently across every sample, every run, and every environment. Doing it by hand doesn't scale or reproduce:

- **Manual QC doesn't scale.** A study can have hundreds or thousands of samples. Running a tool on each one by hand, then comparing hundreds of individual reports, is slow and error-prone.
- **Tool environments conflict.** Each bioinformatics tool needs specific versions and dependencies; installing them all on one machine causes conflicts and "works on my machine" failures.
- **Results must be reproducible.** In a research/regulated setting, a run has to produce identical results months later — which is impossible if tool versions drift.
- **It has to run anywhere.** The same analysis needs to move from a laptop to an HPC cluster to the cloud without being rewritten.

This pipeline solves that: it **automates and standardizes the QC + trimming step** so that any number of samples are processed identically, in parallel, each tool in its own pinned container, with one combined report at the end — and the *same* pipeline runs unchanged locally or in the cloud. It's the reproducible, scalable front door to a larger scientific data platform, where cleaned results feed downstream analytics (see [Roadmap](#roadmap)).

---

## What it does

```
FASTQ reads  →  fastp (trim)  →  FastQC (QC trimmed reads)  →  MultiQC (combined report)
```

- **fastp** — trims low-quality bases and adapters from raw reads; emits cleaned FASTQ + a QC report.
- **FastQC** — runs quality control on the trimmed reads (one task per sample, in parallel).
- **MultiQC** — aggregates the fastp and FastQC reports into a single interactive HTML dashboard.

Each step runs in its own **version-pinned container**, so results are reproducible across machines.

---

## Pipeline design

- **Dataflow model:** processes connected by channels; the workflow infers execution order.
- **Fan-out:** the samplesheet becomes a channel — one parallel task per sample.
- **Fan-in:** `MultiQC` gathers every tool's report via `.mix()` + `.collect()` into one run.
- **Portable:** pipeline logic is separated from infrastructure — the same code runs locally or on the cloud by switching a config profile.

---

## Repository structure

```
rnaseq-qc/
├── main.nf                 # workflow wiring (fastp → FastQC → MultiQC)
├── nextflow.config         # params, docker profile, resource limits
├── samplesheet.csv         # input samples (sample_id, fastq URL)
├── modules/
│   ├── fastp.nf            # trimming process
│   ├── fastqc.nf           # quality-control process
│   └── multiqc.nf          # report-aggregation process
└── README.md
```

Generated at runtime (git-ignored): `work/`, `results/`, `.nextflow/`, execution reports.

---

## Input

A CSV samplesheet with a header and one row per sample:

```csv
sample,fastq
SRR11028503,https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR110/003/SRR11028503/SRR11028503.fastq.gz
SRR11028506,https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR110/006/SRR11028506/SRR11028506.fastq.gz
```

Sample data is sourced from the [European Nucleotide Archive (ENA)](https://www.ebi.ac.uk/ena) — real single-end RNA-seq reads, not synthetic test data.

---

## Requirements

- [Nextflow](https://www.nextflow.io/) (Java 17+)
- [Docker](https://www.docker.com/) (Docker Desktop on macOS/Windows)

No bioinformatics tools need to be installed locally — each runs in its container.

---

## Usage

```bash
# Run locally with Docker
nextflow run main.nf -profile docker

# Resume a previous run (reuses cached completed tasks)
nextflow run main.nf -profile docker -resume

# Override parameters
nextflow run main.nf -profile docker --input my_samplesheet.csv --outdir my_results
```

### Output

```
results/
├── fastp/      # trimmed reads + fastp JSON reports
├── fastqc/     # per-sample FastQC reports
└── multiqc/
    └── multiqc_report.html   # ← open this: combined QC dashboard
```

Open the report:

```bash
open results/multiqc/multiqc_report.html
```

---

## Configuration notes

- **Pinned containers** — every process pins an exact image version (no `:latest`) for reproducibility.
- **Resource limits** — per-process `cpus`/`memory` declared in `nextflow.config`.
- **Concurrency control** — `executor.queueSize` caps parallel tasks so local runs don't exhaust memory. (In the cloud, per-task instances remove this constraint.)

---

## Engineering notes (real issues solved)

- **Docker mount permission (exit 125):** macOS protects `~/Documents`; relocated the project so Docker could mount the work directory.
- **Out-of-memory kills (exit 137):** too many memory-heavy tasks running in parallel on real data — resolved by declaring per-process memory and capping concurrency with `executor.queueSize`. This is also the motivation for cloud execution, where AWS Batch right-sizes an instance per task.
- **Debugging approach:** inspect the failed task's work directory (`.command.sh`, `.command.err`, `.exitcode`) to find the exact cause.

---

## Roadmap

- [x] Multi-stage containerized pipeline (fastp → FastQC → MultiQC), working locally on real ENA data
- [ ] Automated data ingestion (ENA API → samplesheet generation)
- [ ] CI/CD — GitHub Actions: lint + test profile on every push
- [ ] Cloud execution via Seqera Platform on AWS Batch (S3 work directory, Spot instances)
- [ ] Infrastructure-as-Code — Terraform for S3 / IAM / AWS Batch
- [ ] Downstream Databricks lakehouse — medallion (Bronze/Silver/Gold), Delta Lake, Unity Catalog

---

## Tech stack

Nextflow · Docker · fastp · FastQC · MultiQC · BioContainers · (planned: Seqera Platform, AWS Batch, S3, Terraform, Databricks)