import Foundation

// MARK: - MeridianKind base + semantic protocols
//
// Every domain kind declared in a `.merconfig` whose parent isn't a primitive
// scalar (String, Number, …) lowers to a generated `<KindName>Kind` protocol +
// conforming `<KindName>` struct. The generated protocol composes one of the
// semantic bases below so the type system carries the kind's role through
// the workflow:
//
//     A pull request is a kind of thing.
//         → struct PullRequest: PullRequestKind
//         → protocol PullRequestKind: MeridianThing
//
//     An audit note is a kind of event.
//         → struct AuditNote: AuditNoteKind
//         → protocol AuditNoteKind: MeridianEvent
//
// `MeridianKind` is the structural baseline every semantic protocol composes.
// It carries the `Hashable`/`Codable`/`Sendable` conformances the runtime
// assumes (so `State`'s opaque traversal can JSON-round-trip dotted lookups)
// and the `id: String` requirement every generated struct already satisfies.
//
// The semantic protocols (`MeridianThing`, `MeridianEvent`, `MeridianAction`,
// `MeridianTool`, `MeridianProcess`, `MeridianMessage`, `MeridianSignal`,
// `MeridianFact`, `MeridianRole`, `MeridianVerdict`, plus the software/AI
// workflow bases below) are intentionally empty marker protocols. The
// discriminating value is in the type name, not in the contract — keeping the
// contracts empty avoids forcing host vocabulary authors into an unnatural
// baseline (e.g. `Event` doesn't always have a fixed `occurredAt`; `Action`
// doesn't always carry an explicit verb field).
//
// The `Meridian` prefix is required because several bare names already
// resolve to other types in scope:
//   • `Event`    — public struct in MeridianRuntime (telemetry record).
//   • `Process`  — public class in Foundation (subprocess host).
//   • `Tool`     — used as the discriminating noun in many runtime APIs;
//                  prefixed for symmetry with the rest.
// Prefixing every base uniformly avoids surprise for vocabulary authors.

public protocol MeridianKind: Hashable, Codable, Sendable {
    var id: String { get }
}

/// Default base for `A foo is a kind of thing.` — generic identity-bearing
/// entity. Use for nouns that represent things in your domain (orders,
/// customers, repositories, pull requests, …).
public protocol MeridianThing: MeridianKind {}

/// Base for `A foo is a kind of event.` — something that occurred, suitable
/// for emit / wait / observability. Examples: `audit note`, `policy decision`.
public protocol MeridianEvent: MeridianKind {}

/// Base for `A foo is a kind of action.` — a discrete operation a workflow
/// can take. Examples: `repair`, `merge`, `dispatch`.
public protocol MeridianAction: MeridianKind {}

/// Base for `A foo is a kind of tool.` — a domain capability or instrument
/// that does work. It may be backed by a runtime-registered callable, but the
/// vocabulary meaning is "does something", not "is an external system".
public protocol MeridianTool: MeridianKind {}

/// Base for `A foo is a kind of system.` — an external or internal platform,
/// server, or product the workflow reasons about or talks to.
public protocol MeridianSystem: MeridianKind {}

/// Base for `A foo is a kind of integration.` — a configured connector,
/// account, webhook, or adapter linking Meridian to another system.
public protocol MeridianIntegration: MeridianKind {}

/// Base for `A foo is a kind of artifact.` — a software/work product such as
/// a repository, pull request, patch, document, report, or build log.
public protocol MeridianArtifact: MeridianKind {}

/// Base for `A foo is a kind of service.` — a hosted API or service endpoint
/// that provides behaviour to workflows.
public protocol MeridianService: MeridianKind {}

/// Base for `A foo is a kind of agent.` — an autonomous AI or software actor,
/// distinct from human/organizational roles.
public protocol MeridianAgent: MeridianKind {}

/// Base for `A foo is a kind of model.` — an LLM, embedding model, classifier,
/// evaluator, or other model used by an AI workflow.
public protocol MeridianModel: MeridianKind {}

/// Base for `A foo is a kind of dataset.` — a corpus, eval set, index,
/// knowledge base, or other collection used as data.
public protocol MeridianDataset: MeridianKind {}

/// Base for `A foo is a kind of storage.` — a database, bucket, queue, cache,
/// vector store, file store, or artifact registry.
public protocol MeridianStorage: MeridianKind {}

/// Base for `A foo is a kind of credential.` — an API key, token, secret,
/// service account, or auth configuration.
public protocol MeridianCredential: MeridianKind {}

/// Base for `A foo is a kind of policy.` — a guardrail, routing rule,
/// approval policy, retention policy, or other governing constraint.
public protocol MeridianPolicy: MeridianKind {}

/// Base for `A foo is a kind of environment.` — a runtime target or boundary
/// such as prod, staging, a workspace, tenant, cluster, or region.
public protocol MeridianEnvironment: MeridianKind {}

/// Base for `A foo is a kind of resource.` — infrastructure or allocatable
/// capacity such as a host, container, compute job, or cloud resource.
public protocol MeridianResource: MeridianKind {}

/// Base for `A foo is a kind of metric.` — a measured signal, score, SLO, eval
/// result, or quantitative quality indicator.
public protocol MeridianMetric: MeridianKind {}

/// Base for `A foo is a kind of memory.` — agent/session memory, retained
/// context, conversation history, or long-term knowledge store.
public protocol MeridianMemory: MeridianKind {}

/// Base for `A foo is a kind of process.` — a long-running unit of work
/// (workflow run, build, deployment) with lifecycle state.
public protocol MeridianProcess: MeridianKind {}

/// Base for `A foo is a kind of message.` — a one-way communication payload.
/// Examples: `notification`, `email`, `chat message`.
public protocol MeridianMessage: MeridianKind {}

/// Base for `A foo is a kind of signal.` — a named broadcast that workflows
/// can `wait for` or `deliver`. Examples: `cancellation`, `dispatch ready`.
public protocol MeridianSignal: MeridianKind {}

/// Base for `A foo is a kind of fact.` — an asserted piece of knowledge
/// (the workflow's evidence base). Examples: `claim`, `observation`.
public protocol MeridianFact: MeridianKind {}

/// Base for `A foo is a kind of role.` — an actor identity used in
/// permissions and approvals. Examples: `reviewer`, `account manager`.
public protocol MeridianRole: MeridianKind {}

/// Base for `A foo is a kind of verdict.` — a decision outcome the workflow
/// or an approver produced. Examples: `approval`, `validation result`.
public protocol MeridianVerdict: MeridianKind {}
