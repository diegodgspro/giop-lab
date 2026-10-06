# Integration security and identity v0.1

Phase 3A design only. No credentials, users, profiles, OAuth clients, media types or actions created. Automatic writes NOT ENABLED.

## Identity and minimum proposed privileges

Dedicated user/profile/client: giop-lab-zabbix-glpi-integration. Never reuse GIOP-LAB GLPI Agent Inventory (inventory scope only). Existing GIOP-LAB CLI Automation is diagnostic/bootstrap access, not a runtime identity: repository Test-GlpiApiContext explicitly probes Admin profile, and successful Phase 2 seed mutations do not prove least privilege. Exact existing user/client effective grants were not audited through UI; do not infer authorization from client name or API scope. Retain it only for read-only 3A investigation.

Use separate OAuth client scope api with dedicated central-interface technical user and custom empty profile. Prefer a GLPI-supported grant tied to this user/profile. The live schema supports api bearer access but does not prove api-scope Client Credentials user/profile behavior; do not reuse the inventory grant configuration. Existing CLI password grant is observed working. Operator must confirm allowed grant/configuration and local secret handling before creation. No Admin/Super-Admin profile, no inventory/user scope for convenience.

| Capability | Smallest proposed grant | Constraints/gate |
| --- | --- | --- |
| Search/read own integration Tickets | Ticket See my ticket (READMY), created/requester technical user | Verify create defaults preserve ownership; exact-marker search must see own tickets. No See all tickets by default |
| Create Ticket | Ticket Create | Authorized existing entity only, default New Incident; no assignment/solution privileges |
| Update allowed fields | Ticket Update only if later approved PATCH actually needed | Service whitelist urgency/impact after confirmation; never overwrite human content/name/external_id. GLPI Update is broader than field-level policy; dry-run profile can omit it |
| Follow-up read | Public follow-up visibility (SEEPUBLIC), parent ticket readability | Reconciliation marker uses public synthetic content; no private data requirement |
| Follow-up add | Add follow-up to my tickets (ADDMY/ADDMYTICKET) | Source ITILFollowup.php confirms parent visibility and role checks; no ADDALL or edit/delete rights |
| Computer identity | Computers Read | Needed Computer 1 in entity 0; no create/update/delete/purge |
| NetworkEquipment identity | Network equipment Read only if mapping later requires it | Pilot is Computer only; no need to grant this now |
| State transitions | No automatic existing-ticket transitions | Lifecycle matrix must prohibit integration solve/close/reopen; create initial default only |

Source review: live src/Ticket.php getRights exposes READMY, READALL, Create/Update through base rights; src/ITILFollowup.php canView requires public/private visibility plus parent read and canCreate checks ADDMY/role rights. Exact rights combination has NOT been validated with dedicated identity, which does not exist. If READMY cannot support API search/ownership, stop and document concrete denied operation; do not silently expand to Admin or See all. Field policy enforcement is a service boundary requirement, not a claim that GLPI profile grants are field-scoped.

Root entity 0 currently holds Computer 1. Nonrecursive entity-0 access is still access to shared root assets, not isolation by synthetic name. Operator must approve that scope. Moving assets or creating a dedicated entity is outside 3A. Do not create Entity just to bypass authorization.

## Exact proposed operator configuration steps (not executed)

1. GLPI Administration > Profiles: create custom central/standard-interface profile giop-lab-zabbix-glpi-integration from empty rights, not an Admin clone. Set only Ticket See my ticket/Create, public follow-up Read/Add to my tickets, Computer Read. Leave update off for dry-run; later enable Ticket Update only with approved field policy. NetworkEquipment Read stays off for current pilot.
2. In profile lifecycle/status matrix deny automatic Solved/Closed/reopen transitions; no assign/steal/priority override/delete/purge, administration, user/profile/entity management, inventory or asset writes. Review exact translated UI labels against rights concepts above.
3. Administration > Users: create local technical user of the same name with no inherited broad memberships. Add exactly this profile authorization for Root entity ID 0, recursive=false, only after root-scope approval. Set that profile/entity as defaults. Confirm created-ticket ownership semantics in a later explicitly authorized test.
4. Setup > General > API / RESTful API V2: review GIOP-LAB CLI Automation and inventory client separately without exposing secrets. Create a dedicated OAuth client with api scope and an approved user-bound grant supported by this installation; do not guess that inventory Client Credentials grants ticket access. Store secrets only in ignored local configuration/secret storage; never paste them into documents.
5. With new identity, run read-only exact CI/entity, Ticket search, follow-up visibility and negative access checks first. No writes in 3A. Later write tests need explicit authorization and synthetic evidence proving Create, field whitelist and ownership. Denials remain release blockers rather than reasons for broad access.

These are operator actions requiring UI/profile/grant decisions. STOP before executing them. No user/profile/client was created and no commit is authorized while decisions remain unresolved.

## Receiver contract

Future receiver uses independent random shared secret authenticated in a fixed header, constant-time comparison, rotation/version support and replay protection through durable operation IDs. Never use GLPI token as webhook secret. Fixed allowed Zabbix instance/source network and fixed receiver path; fixed GLPI origin and /api.php/v2.3.0 routes. No URLs, destinations, headers or entity/profile choices accepted from payload. Network source allowlist supplements authentication, never replaces it.

Accept POST application/json only, maximum 32 KiB, UTF-8, schema version 1, bounded IDs/string lengths/depth and explicit enums; reject extra URL fields, multi-CI ambiguity, invalid timestamps and noncanonical instance values. Enforce bounded receive/processing timeouts, concurrency, rate and queue capacity; durable acceptance precedes 2xx. Invalid -> 400/413/415; unauthenticated -> 401/403; unavailable state -> 503, no outbound writes. Do not drop Recovery silently during rate limiting.

LAB HTTP exception applies only to isolated Docker service-to-service paths. Future integration service joins only required application networks, not either database network; no host ports by default, host mounts/socket, privileged mode or host networking. Future cross-host traffic requires TLS with certificate validation; never disable verification. Payload itself cannot grant broader connectivity.

Logs include operation/episode IDs, decision, policy version, result status and timing; redact Authorization, OAuth form fields, secrets, cookies and tokens. Do not log raw bodies, credentials, curl arguments or error responses that echo them. Sanitize HTML/newlines and untrusted text. State stores minimized synthetic fields and digests, no credential values. Limit file permissions, retention and access to backups; protect runtime process/Docker environment exposure. No production secrets are generated now.

Official context: https://help.glpi-project.org/documentation/modules/administration/profiles/profiles and https://help.glpi-project.org/documentation/modules/configuration/general/api/restful-api-v2 . Live source/schema and dedicated-identity tests govern acceptance.
