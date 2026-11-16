import type { MCPServerConfig } from './types'

export interface BuildinMCPServerConfig {
  id: string
  name: string
  description: string
  url: string
}

const BUILTIN_MCP_BASE_URL = 'https://mcp.chatboxai.app'

// [Chatbox CE] the built-in MCP servers are hosted at mcp.chatboxai.app and are
// metered by Chatbox AI license keys; the Community Edition ships none. The
// upstream table is kept below (commented) so the list can be restored by
// simply re-enabling entries.
export const BUILTIN_MCP_SERVERS: BuildinMCPServerConfig[] = [
  // {
  //   id: 'fetch',
  //   name: 'Fetch',
  //   description:
  //     'This server enables LLMs to retrieve and process content from web pages, converting HTML to markdown for easier consumption.',
  //   url: `${BUILTIN_MCP_BASE_URL}/fetch`,
  // },
  // {
  //   id: 'arxiv',
  //   name: 'arXiv',
  //   description: 'MCP server for accessing arXiv papers',
  //   url: `${BUILTIN_MCP_BASE_URL}/arxiv`,
  // },
  // {
  //   id: 'context7',
  //   name: 'Context7',
  //   description: 'Retrieves up-to-date documentation and code examples for any library.',
  //   url: `${BUILTIN_MCP_BASE_URL}/context7`,
  // },
]

export function getBuiltinServerConfig(id: string, licenseKey?: string): MCPServerConfig | null {
  const config = BUILTIN_MCP_SERVERS.find((s) => s.id === id)
  if (!config) {
    return null
  }
  const license = licenseKey
  return {
    id,
    name: config.name,
    enabled: true,
    protocolMode: 'legacy',
    transport: {
      type: 'http',
      url: config.url,
      headers: license ? { 'x-chatbox-license': license } : undefined,
    },
  }
}
