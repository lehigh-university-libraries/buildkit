# openai-htr

Use OpenAI ChatGPT to transcribe images with handwritten text.

## Secrets

Requires an environment variable `OPENAI_API_KEY`

If deploying this in Kubernetes, you can create the secret via

```
 kubectl create secret generic openai \
  --from-literal=api-key=$OPENAI_API_KEY
```
