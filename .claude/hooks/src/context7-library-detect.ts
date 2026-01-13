/**
 * Context7 Library Detection Hook (PostToolUse:Read)
 *
 * After reading files, detects imports from popular libraries
 * and suggests using Context7 for current documentation.
 */

import { readFileSync, existsSync } from 'fs';
import { basename, extname, join } from 'path';
import { homedir } from 'os';

interface HookInput {
  tool_name: string;
  tool_input: {
    file_path?: string;
  };
  tool_output?: {
    content?: string;
  };
  session_id?: string;
}

interface HookOutput {
  hookSpecificOutput?: {
    hookEventName: string;
    additionalContext?: string;
  };
}

// Libraries that Context7 has good documentation for
const LIBRARY_WHITELIST: Record<string, string> = {
  // JavaScript/TypeScript
  'react': '/facebook/react',
  'react-dom': '/facebook/react',
  'next': '/vercel/next.js',
  'next/': '/vercel/next.js',
  '@next/': '/vercel/next.js',
  'vue': '/vuejs/vue',
  'nuxt': '/nuxt/nuxt',
  'svelte': '/sveltejs/svelte',
  'angular': '/angular/angular',
  '@angular/': '/angular/angular',
  'express': '/expressjs/express',
  'fastify': '/fastify/fastify',
  'hono': '/honojs/hono',
  'prisma': '/prisma/prisma',
  '@prisma/client': '/prisma/prisma',
  'drizzle-orm': '/drizzle-team/drizzle-orm',
  'tailwindcss': '/tailwindlabs/tailwindcss',
  '@tanstack/react-query': '/tanstack/query',
  'zod': '/colinhacks/zod',
  'trpc': '/trpc/trpc',
  '@trpc/': '/trpc/trpc',
  'axios': '/axios/axios',
  'lodash': '/lodash/lodash',
  'date-fns': '/date-fns/date-fns',
  'dayjs': '/iamkun/dayjs',
  'mongoose': '/Automattic/mongoose',
  'sequelize': '/sequelize/sequelize',
  'typeorm': '/typeorm/typeorm',
  'graphql': '/graphql/graphql-js',
  '@apollo/client': '/apollographql/apollo-client',
  'socket.io': '/socketio/socket.io',
  'redux': '/reduxjs/redux',
  '@reduxjs/toolkit': '/reduxjs/redux-toolkit',
  'zustand': '/pmndrs/zustand',
  'jotai': '/pmndrs/jotai',
  'valtio': '/pmndrs/valtio',
  'react-hook-form': '/react-hook-form/react-hook-form',
  'formik': '/jaredpalmer/formik',
  // Python
  'fastapi': '/tiangolo/fastapi',
  'django': '/django/django',
  'flask': '/pallets/flask',
  'sqlalchemy': '/sqlalchemy/sqlalchemy',
  'pydantic': '/pydantic/pydantic',
  'requests': '/psf/requests',
  'numpy': '/numpy/numpy',
  'pandas': '/pandas-dev/pandas',
  'pytorch': '/pytorch/pytorch',
  'torch': '/pytorch/pytorch',
  'tensorflow': '/tensorflow/tensorflow',
  'keras': '/keras-team/keras',
  'langchain': '/langchain-ai/langchain',
};

// Session cache to avoid repeated suggestions
const sessionCache = new Set<string>();

/**
 * Extract imports from JavaScript/TypeScript code.
 */
function extractJSImports(code: string): string[] {
  const imports: string[] = [];

  // ES6 imports: import X from 'library'
  const esImportRe = /import\s+(?:[\w{},\s*]+\s+from\s+)?['"]([^'"]+)['"]/g;
  let match;
  while ((match = esImportRe.exec(code)) !== null) {
    const lib = match[1].split('/')[0];
    if (lib && !lib.startsWith('.') && !lib.startsWith('@')) {
      imports.push(lib);
    } else if (lib.startsWith('@')) {
      // Scoped package: @scope/package
      const scopedLib = match[1].split('/').slice(0, 2).join('/');
      imports.push(scopedLib);
    }
  }

  // CommonJS: require('library')
  const requireRe = /require\s*\(\s*['"]([^'"]+)['"]\s*\)/g;
  while ((match = requireRe.exec(code)) !== null) {
    const lib = match[1].split('/')[0];
    if (lib && !lib.startsWith('.') && !lib.startsWith('@')) {
      imports.push(lib);
    } else if (lib.startsWith('@')) {
      const scopedLib = match[1].split('/').slice(0, 2).join('/');
      imports.push(scopedLib);
    }
  }

  return [...new Set(imports)];
}

/**
 * Extract imports from Python code.
 */
function extractPythonImports(code: string): string[] {
  const imports: string[] = [];

  // import X, from X import Y
  const importRe = /(?:^|\n)\s*(?:from\s+([\w.]+)|import\s+([\w.]+))/g;
  let match;
  while ((match = importRe.exec(code)) !== null) {
    const lib = (match[1] || match[2]).split('.')[0];
    if (lib) {
      imports.push(lib);
    }
  }

  return [...new Set(imports)];
}

/**
 * Check if Context7 is configured.
 */
function isContext7Configured(): boolean {
  const homeDir = homedir();
  const claudeJson = join(homeDir, '.claude.json');

  if (existsSync(claudeJson)) {
    try {
      const config = JSON.parse(readFileSync(claudeJson, 'utf-8'));
      return !!(config.mcpServers?.context7 || config.projects?.some?.((p: { mcpServers?: { context7?: unknown } }) => p.mcpServers?.context7));
    } catch {
      return false;
    }
  }

  return false;
}

async function main() {
  try {
    const input: HookInput = JSON.parse(readFileSync(0, 'utf-8'));

    // Only process Read tool results
    if (input.tool_name !== 'Read') {
      console.log('{}');
      return;
    }

    const filePath = input.tool_input.file_path || '';
    const content = input.tool_output?.content || '';

    if (!content || !filePath) {
      console.log('{}');
      return;
    }

    // Only check JS/TS/Python files
    const ext = extname(filePath).toLowerCase();
    const isJS = ['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs'].includes(ext);
    const isPython = ext === '.py';

    if (!isJS && !isPython) {
      console.log('{}');
      return;
    }

    // Extract imports
    const imports = isJS ? extractJSImports(content) : extractPythonImports(content);

    if (imports.length === 0) {
      console.log('{}');
      return;
    }

    // Find imports that are in whitelist
    const matchedLibraries: Array<{ name: string, context7Id: string }> = [];

    for (const imp of imports) {
      const impLower = imp.toLowerCase();

      // Direct match
      if (LIBRARY_WHITELIST[impLower]) {
        matchedLibraries.push({ name: imp, context7Id: LIBRARY_WHITELIST[impLower] });
        continue;
      }

      // Prefix match (e.g., 'next/image' → 'next/')
      for (const [prefix, id] of Object.entries(LIBRARY_WHITELIST)) {
        if (prefix.endsWith('/') && impLower.startsWith(prefix.slice(0, -1))) {
          matchedLibraries.push({ name: imp, context7Id: id });
          break;
        }
      }
    }

    if (matchedLibraries.length === 0) {
      console.log('{}');
      return;
    }

    // Check if Context7 is configured
    if (!isContext7Configured()) {
      console.log('{}');
      return;
    }

    // Dedupe by file to avoid spamming
    const sessionId = input.session_id || 'default';
    const cacheKey = `${sessionId}:${basename(filePath)}`;

    if (sessionCache.has(cacheKey)) {
      console.log('{}');
      return;
    }

    sessionCache.add(cacheKey);

    // Limit to 3 libraries to avoid noise
    const topLibraries = matchedLibraries.slice(0, 3);
    const libNames = topLibraries.map(l => l.name).join(', ');
    const libIds = topLibraries.map(l => `${l.name} → ${l.context7Id}`).join('\n  ');

    const output: HookOutput = {
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: `[Context7] Detected libraries with current docs available:
  ${libIds}

Tip: Use "context7" or /docs-lookup for up-to-date documentation.
Example: "Get React hooks docs using context7"`
      }
    };

    console.log(JSON.stringify(output));
  } catch {
    console.log('{}');
  }
}

main().catch(() => console.log('{}'));
