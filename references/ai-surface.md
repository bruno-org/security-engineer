# AI Surface

Applies to any system that sends a prompt to a language model at runtime, retrieves documents for one, or exposes a tool to one. Same shape as the playbooks in layer-playbooks.md: Decisions, MUST, SHOULD, MAY, Acceptance check, Friction.

This is a conditional fourteenth layer. It applies only when the system ships a model or agent feature, and it is recorded as Not applicable, with the reason, when it does not. Shipping a model feature adds an attack surface that the other thirteen layers do not cover, and it does not replace any of them. Everything in layer 2 and layer 3 still applies underneath, because the model reaches your data through the same handlers and the same tables.

---

## The instruction and data problem

A model receives one token stream. The system prompt, the user's message, a retrieved document, a page fetched by a browsing tool, a file, an email body, a code comment, a tool result, and the output of another model all arrive in that same stream and carry the same weight. Any content the model reads is potentially an instruction to it. There is no delimiter, header, or role marker that reliably separates the two, and no known prompt wording that makes the separation hold under an adversary.

Design for the injection landing. Filtering hostile phrasing and instructing the model to ignore instructions it finds in data reduce the hit rate on unsophisticated payloads. They are mitigations, never controls, and nothing may depend on them. The control is the code around the model: what the model is permitted to reach, and who decides.

## The lethal combination

Watch for three properties in one context: access to private data, exposure to content from outside your trust boundary, and a channel that sends data outward. Any two are usually manageable. All three together mean text written by an attacker can read secrets and ship them out, with no vulnerability in your code at all.

The outbound channel is wider than a network call. It includes an image the client loads from a model-supplied URL, a markdown link with data in the query string, a webhook, an outbound email, a commit message, a support ticket the model files, and a hostname a tool resolves. Break one leg of the three. The usual choices are restricting the outbound channel to an allowlist of destinations and blocking automatic image and link fetches built from untrusted content, or isolating the untrusted content in a context that holds no private data and no privileged tool.

---

## The playbook

**Decisions.** Provider and model, whether the feature is a single prompt or an agent with tools, what the model is allowed to reach, which runs act under a human identity and which run unattended, which actions are reversible, where the spend cap sits, how the feature is switched off in a hurry, and what data leaves the building.

**MUST**
- **Authorization belongs to the calling system.** The model decides what to attempt. The code that executes the attempt decides whether it is permitted, using the verified identity of the human on whose behalf it runs. This is the layer 2 rule applied to a caller that writes its own requests.
- The model's execution context never holds broader permission than that user has. No service key, no bypass role, no cross-tenant reader, no shared connection. An action the user cannot perform in the interface is an action the model cannot perform for them.
- **Every tool exposed to a model is an API endpoint whose caller is unpredictable.** Each one validates its arguments against a schema, enforces its own authorization inside the tool, and is scoped to one narrow job. A tool that reads one resource type by identifier is safe to expose. A tool that runs arbitrary SQL, shell, or HTTP is the model's privilege escalation path.
- Tools are classified read-only or state-changing at definition time. Irreversible and outward-facing actions require human confirmation before execution: sending a message or email, spending or moving money, deleting data, publishing, granting access, and writing outside the working scope. The confirmation shows the resolved arguments, meaning the actual recipient, amount, and target identifier, rather than the model's description of them.
- **Model output is untrusted input to whatever consumes it.** It never goes directly into a SQL statement, a shell command, an eval or deserializer, raw HTML, a redirect location, a file path, or an argument another service trusts. Encode and validate at the sink exactly as with user input.
- Retrieval is filtered by the requesting user's permissions at query time, by a metadata filter on the query plus the same row rules layer 3 requires on the underlying store. Filtering only when documents are indexed leaves the assistant as a way to read other tenants' documents through a well-phrased question.
- Documents entering a retrieval index are an injection channel. Content submitted or uploaded by users, scraped from the web, or synced from a shared drive is untrusted, and a context holding it gets no privileged tool and no other tenant's data.
- **Instructions arrive in non-text inputs too.** Text rendered inside an image, white or zero-size text in a PDF, document metadata, spreadsheet comments, and alternative text in HTML are all read by a multimodal model and are all untrusted content. The upload rules of layer 2, meaning type verification, size caps, and no trust in the extension, apply on top rather than instead.
- Code, queries, or commands the model writes execute only in a sandbox with no credentials mounted, no network beyond an allowlist, an ephemeral filesystem, and a processor, memory, and wall-clock cap. Executing model output on the application host hands the host to whoever writes the injected text.
- **Unattended runs get their own identity.** A scheduled agent, a queue worker, or a webhook-triggered agent has no human to confirm anything, so it acts under a dedicated service identity with its own narrow permissions and its own audit trail, and its tool set is read-only or restricted to reversible actions.
- **Prompts, skills, agent definitions, and connected tool servers are executable instructions from a third party.** Review before installation, pin to an immutable version or digest, and update deliberately. Tool names and tool descriptions are text the model obeys, so they are part of the review.
- Per-user and per-tenant quotas on model calls, a cap on output tokens, a request timeout, and a spend alert on the provider account. No unauthenticated route reaches a paid model call. The provider key stays server-side, and the browser never calls the provider directly.
- Personal data is minimized before it leaves. Know and write down whether the provider trains on inputs, in which region it processes, and how long it retains. The provider goes on the processor record required by layer 12 and into the privacy notice.

**SHOULD**
- Untrusted content handled in an isolated context: a separate call or sub-agent with no private data and no privileged tool, returning a typed, validated result to the privileged context.
- Log the prompt, the identifiers of retrieved documents, every tool call with its arguments, the authorization decision, and the final output, keyed by request identifier and acting user. These logs carry everything the user typed and everything the model read, so they are scrubbed under the layer 7 rules, retention-bounded, and access-restricted like the underlying data.
- Constrained output: request a typed tool call or an enumerated value rather than free text, and validate against the schema before acting. Reject a malformed result instead of repairing it.
- Tool results treated as untrusted content on the way back in. A fetched page, a read email, a search result, and a database row holding user-written text all re-enter the context as text an attacker may have authored, and the tool gains no trust from having been called by the model.
- Hard limits on agent loops: maximum iterations, maximum tool calls per run, wall-clock ceiling, and a bound on models calling models. Every iteration is a billed call.
- Context boundaries per user and per tenant, including cache keys. A prompt cache or a conversation store keyed without the tenant serves one customer's content to another.
- An adversarial test set of injection payloads kept in the repository and run in the pipeline. A prompt edit or a model version change alters behavior with no code diff, so the checks below are automated rather than performed once by hand.
- Connected tool servers re-reviewed on update, since a server can add tools or rewrite its descriptions after it was approved.
- Instruction hierarchy stated in the system prompt and a filter on known injection patterns, recorded as rate reduction with nothing depending on either.
- The system prompt and the tool list treated as public, because extraction works. They hold no credential, no internal hostname, and no rule whose value depends on staying hidden.
- Streaming output encoded at the sink chunk by chunk. A markdown or HTML renderer fed partial output is the same injection sink as one fed the finished response.
- A kill switch that is documented and rehearsed: a flag that disables the feature without a deploy, plus a provider key rotation someone has actually performed, so an abused or misbehaving agent stops within minutes.

**MAY**
- A separate provider account or project per environment, each with its own key and its own spend cap.
- A self-hosted model where the data class makes sending content to a third party unacceptable.
- A canary string placed in the system prompt, alerting if it ever appears in output or in an outbound tool argument.
- Classification on model output that reaches another user's screen.
- All agent network traffic routed through an egress proxy that allowlists destinations and logs every one, so the outbound channel is enumerable after an incident.
- A second model reviewing the arguments of high-risk tool calls before execution, added on top of the human confirmation rather than in place of it.

**Acceptance check.** Run before the feature ships, and again on every prompt, model, or tool change.

- Put a document into the retrieval index whose text instructs the model to call a privileged tool and send the result somewhere, then ask a question that retrieves it. Confirm no privileged tool fires, no outbound request leaves, and the injected text appears in the log for review.
- Call each tool with a valid session for user A and an identifier belonging to user B. Confirm the denial comes from the tool's own authorization code by removing the model from the loop and invoking the tool function directly with the same arguments.
- Render a model response containing script markup, an inline event handler, and an image tag pointing at an external host. Confirm all of it displays as text and that no request goes to that host.
- Drive one account past its per-user quota and confirm further calls are refused, counted, and alerted, and that the refusal does not deny service to other accounts.
- Ask the model, from an account with no administrative role, to perform an administrative action. Confirm the failure is raised at the tool boundary and logged as a denial.
- Upload a file carrying instructions a reader does not see, meaning white text in a PDF or text drawn inside an image, ask for a summary, and confirm no tool fires and the instructions are reported as document content.
- Extract the system prompt with a few known phrasings and confirm the recovered text contains nothing that was meant to stay private.
- From inside the code sandbox, attempt to read the process environment, reach the cloud metadata address, and open a connection to an arbitrary host. All three fail.
- Send a prompt containing a fake credential and a fake personal record, then confirm neither value appears in the telemetry destination, matching the layer 7 check.

**Friction.** Rank 1 for authorization, tool scoping, output encoding, retrieval filtering, and quotas: the user notices none of it. Rank 3 for confirmation on irreversible and outward-facing actions, felt on the few actions that deserve it, and worth it because the model will eventually get one wrong. Isolating untrusted content costs a second model call and some latency, which lands on the developer's design and on the response time, never on correctness.

---

## When this layer does not apply

A system that makes no model call at runtime, embeds no agent, maintains no retrieval index, and integrates no vendor feature that sends user content to a model records this layer as Not applicable, with that sentence as the reason.

Two checks before recording it. First, look for the model calls nobody labels as such: a support or search widget, a document summarizer, an editor autocomplete, a transcription step, and moderation, fraud, or enrichment vendors that call a model on your behalf. Any of those makes the layer apply, with the vendor's terms answering the privacy items. Second, using an assistant to write the code does not activate this layer, which covers what the shipped product does at runtime. The security of assistant-generated code belongs to the Five Defaults and to layer 10.
