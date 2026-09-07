import path from "path"
import { fileURLToPath } from "url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "alo7-doc-tools")

export const Alo7DocToolsPlugin = async () => ({
  config: async (config) => {
    config.mcp ||= {}
    config.mcp["alo7-redmine"] = {
      type: "local",
      command: [path.join(root, "redmine-mcp.sh"), "-y", "@thelabnyc/redmine-mcp@0.5.0"],
      environment: {
        REDMINE_URL: "https://redmine.saybot.net",
        REDMINE_API_KEY: "{env:REDMINE_API_KEY}",
      },
      enabled: true,
    }
  },
})
