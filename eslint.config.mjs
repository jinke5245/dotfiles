import { defineConfig } from "eslint/config";
import globals from "globals";
import js from "@eslint/js";
import json from "@eslint/json";
import yaml from "eslint-plugin-yml";
import markdown from "@eslint/markdown";
import prettier from "eslint-config-prettier";
import jsonschema from "eslint-plugin-json-schema-validator";

export default defineConfig([
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
  },
  {
    files: ["**/*.{json,jsonc,json5,yml,yaml}"],
    rules: {
      "json-schema-validator/no-invalid": "error",
    },
  },
  {
    files: ["**/*.md"],
    plugins: { markdown },
    language: "markdown/gfm",
    extends: ["markdown/recommended"],
  },
  prettier,
]);
