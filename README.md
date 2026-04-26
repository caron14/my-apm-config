# My Agent Package Manager(APM) Configuration

A configuration repository for APM (Agent Package Manager) to standardize AI utilization across the organization.

## Overview

This repository manages standard sets of MCP (Model Context Protocol) server configurations and prompts used by AI agents such as GitHub Copilot and Claude Code.

It is intended to serve as a base configuration for other projects within the organization.

## Included Configurations

### MCP Servers
- **mcp-bigquery**: MCP for BigQuery operations.
- **mcp-duckvault**: MCP for using Obsidian Vault as a RAG (Retrieval-Augmented Generation) source.

## Setup Instructions

1. **Install uv** (Python package manager)
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. **Install APM**
   ```bash
   curl -sSL https://aka.ms/apm-unix | sh
   ```

3. **Apply Configuration**
   First, update the [Configuration Notes](#configuration-notes) below. Then, run the following command in the root of this repository to install all defined MCP servers:
   ```bash
   apm install
   ```

   *Note: MCP servers are configured to run via `uvx`, so they will be downloaded and executed on-demand. No manual pre-installation of individual MCP servers is required.*

## Configuration Notes

Before running `apm install`, please update the following placeholders in `apm.yml` to match your local environment:

- **mcp-duckvault**:
  - `args`: Change the last argument `"/path/to/your/obsidian/vault"` to the **absolute path** of your Obsidian Vault.
