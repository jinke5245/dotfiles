import { defineConfig, includeIgnoreFile } from "eslint/config";
import globals from "globals";
import js from "@eslint/js";
import json from "@eslint/json";
import yaml from "eslint-plugin-yml";
import markdown from "@eslint/markdown";
import prettier from "eslint-config-prettier";
import jsonschema from "eslint-plugin-json-schema-validator";

export default defineConfig([
  includeIgnoreFile(import.meta.dirname + "/.gitignore"),
  {
    ignores: [
      ".agents/",
      "*-lock.*",
    ],
  },
  {
    files: ["**/*.{js,mjs,cjs}"],
    plugins: { js },
    extends: ["js/recommended"],
    languageOptions: { globals: globals.node },
  },
  {
    files: ["**/*.json"],
    plugins: { json, jsonschema },
    language: "json/json",
    extends: [
      "json/recommended",
      "jsonschema/recommended",
    ],
  },
  {
    files: ["**/*.jsonc"],
    plugins: { json, jsonschema },
    language: "json/jsonc",
    extends: [
      "json/recommended",
      "jsonschema/recommended",
    ],
  },
  {
    files: ["**/*.json5"],
    plugins: { json, jsonschema },
    language: "json/json5",
    extends: [
      "json/recommended",
      "jsonschema/recommended",
    ],
  },
  {
    files: ["**/*.{yml,yaml}"],
    plugins: { yaml, jsonschema },
    language: "yaml/yaml",
    extends: [
      "yaml/recommended",
      "jsonschema/recommended",
    ],
    rules: {
      "yaml/no-empty-document": "off",
      "yaml/no-empty-mapping-value": "off",
    },
  },
  {
    files: ["**/*.md"],
    plugins: { markdown },
    language: "markdown/gfm",
    extends: ["markdown/recommended"],
    rules: {
      "markdown/no-missing-label-refs": "off",
    },
  },
  prettier,
]);
