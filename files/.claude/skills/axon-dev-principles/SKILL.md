---
name: axon-dev-principles
description: Use when reviewing code changes, PRs, or implementations for architectural and quality issues specific to this codebase
---

# Axon Dev Principles

A growing checklist of development principles grounded in real problems found and fixed.

---

## 1. Guard Clauses in Infrastructure/Adapter Clients

**Flag:** Null checks, empty-string checks, and range checks that throw `ArgumentException`, `ArgumentNullException`, or `ArgumentOutOfRangeException` inside infrastructure-layer clients (API adapters, HTTP clients, repository implementations).

**Why wrong:** Infrastructure clients are internal plumbing. By the time a call reaches them, inputs should already have been validated at domain boundaries (controllers, use case handlers, service entry points). Duplicating validation here:
- Creates a false impression that the infrastructure layer "owns" that invariant
- Produces misleading tests that test throwing behavior rather than integration behavior
- Gets removed later anyway, leaving stale tests behind

**What to look for:**
```csharp
// ❌ Guard clause in an adapter/client method
public async Task<bool> AdjustProductPricingAsync(PimcoreProductPricingAdjustmentRequest request, ...)
{
    if (request == null)
        throw new ArgumentNullException(nameof(request));

    if (string.IsNullOrWhiteSpace(request.Key))
        throw new ArgumentException("Product key cannot be empty", nameof(request));
    ...
}

// ✅ Correct: infrastructure method trusts its caller
public async Task<bool> AdjustProductPricingAsync(PimcoreProductPricingAdjustmentRequest request, ...)
{
    _logger.LogInformation("Adjusting product pricing: {Key}", request.Key);
    ...
}
```

**Also flag:** Unit tests whose sole purpose is asserting these guard clauses throw (`ShouldThrow_WhenRequestIsNull`, `ShouldThrow_WhenKeyIsEmpty`, etc.) — they should be removed alongside the guard clauses.

---

## 2. Manual Sanitization When the Framework Already Handles It

**Flag:** Custom string-escaping or injection-prevention utilities (`SanitizeForGraphQL`, `IsGraphQLSafe`, etc.) applied to values that are passed through a typed client or parameterized operation.

**Why wrong:** Typed query clients (e.g., StrawberryShake, Dapper with parameters, EF Core) serialize variables as JSON or use parameterized queries — special characters in values are safe by design. Manual escaping on top of this is:
- Dead weight that obscures intent
- A source of subtle double-escaping bugs
- A sign the original author didn't trust the framework

**What to look for:**
```csharp
// ❌ Manual escaping before a typed operation
var sanitizedKey = SanitizeForGraphQL(request.Key.TrimStart('0'));
var result = await _client.UpdatePrice.ExecuteAsync(sanitizedKey, input, ct);

// ✅ Trust the typed client
var trimmedKey = request.Key.TrimStart('0');
var result = await _client.UpdatePrice.ExecuteAsync(trimmedKey, input, ct);
```

**Exception:** Manual sanitization is appropriate when building raw string queries/templates or constructing file paths/URLs that are not passed through a framework serializer.

---

## 3. Contracts Project: Commands Must Be Records, Not Classes

**Flag:** Command types in `Axon.Contracts` declared as `class` instead of `record`.

**Why wrong:** Commands are immutable intent — they should not be mutated after construction. Using `class` with `{ get; set; }` allows callers to partially construct or mutate them, and produces misleading equality semantics.

**What to look for:**
```csharp
// ❌ Mutable class with empty-string defaults
public class TriggerJobCommand
{
    public string JobName { get; set; } = "";
    public string JobGroup { get; set; } = "";
}

// ✅ Immutable record with required init-only properties
public record TriggerJobCommand
{
    [Required(ErrorMessage = "Job name is required")]
    public required string JobName { get; init; }

    [Required(ErrorMessage = "Job group is required")]
    public required string JobGroup { get; init; }
}
```

**Rule:** Commands → `record` with `required { get; init; }`. Query inputs and responses → `class` with `{ get; set; }` (mutable, populated by handlers).

---

## 4. Contracts Project: Missing Validation Attributes

**Flag:** Contract types (commands, models/DTOs) in `Axon.Contracts` with `required` string properties but no `[Required]` or `[StringLength]` data annotations.

**Why wrong:** The `required` keyword is a compile-time constraint only. Runtime validation (model binding, manual `Validator.ValidateObject`) depends on data annotations. Without them, invalid payloads pass through silently.

**What to look for:**
```csharp
// ❌ No runtime validation
public record RescheduleJobCommand
{
    public required string JobName { get; init; }
    public required string NewCronExpression { get; init; }
}

// ✅ Annotated for runtime validation
public record RescheduleJobCommand
{
    [Required(ErrorMessage = "Job name is required")]
    [StringLength(200, ErrorMessage = "Job name must not exceed 200 characters")]
    public required string JobName { get; init; }

    [Required(ErrorMessage = "Cron expression is required")]
    [StringLength(120, ErrorMessage = "Cron expression must not exceed 120 characters")]
    public required string NewCronExpression { get; init; }
}
```

**Also applies to:** Model/DTO records in `Models/` subfolders — these are validated when returned or bound, so string properties need `[Required]` and `[StringLength]` too.

---

## 5. Contracts Project: Empty String Defaults Instead of `required`

**Flag:** Properties in contract types initialized to `""` or `string.Empty` as a substitute for marking them required.

**Why wrong:** An empty string is a valid (but meaningless) value. Defaulting to `""` means an omitted property silently passes through as an empty string rather than failing validation.

**What to look for:**
```csharp
// ❌ Empty string masks missing values
public class RescheduleJobCommand
{
    public string JobName { get; set; } = "";
    public string NewCronExpression { get; set; } = "";
}

// ✅ required enforces the property is supplied
public record RescheduleJobCommand
{
    [Required(ErrorMessage = "Job name is required")]
    public required string JobName { get; init; }
}
```

**Exception:** Business semantic defaults are acceptable (e.g., `public string Currency { get; init; } = "USD"`) — but these should be documented with an inline comment explaining the default.

---

## 6. Contracts Project: Public Types Missing XML Documentation

**Flag:** `public` types (commands, enums) and their members in `Axon.Contracts` with no `/// <summary>` documentation, especially when names are not self-explanatory.

**Why wrong:** Command and enum names alone don't communicate origin, destination, or intent. Missing docs force readers to trace call sites and source systems to understand semantics.

**What to look for:**
```csharp
// ❌ No context on what this command does or where it flows
public record ChangeCustomerPasswordCommand
{
    public required string CustomerId { get; init; }
    public required string NewPassword { get; init; }
}

// ✅ Documents intent, message flow, and each property
/// <summary>
/// Command to change a customer's password.
/// Sent from External PWA Adapter to Customer Domain Service.
/// </summary>
public record ChangeCustomerPasswordCommand
{
    /// <summary>
    /// The unique identifier of the customer whose password is being changed.
    /// </summary>
    public required string CustomerId { get; init; }

    /// <summary>
    /// The new password to set for the customer.
    /// </summary>
    public required string NewPassword { get; init; }
}

// ❌ No context on what Blocked means
public enum ScheduledJobStatus { Normal, Paused, Complete, Error, Blocked }

// ✅ Each value documents its meaning
/// <summary>
/// Represents the current execution state of a scheduled job.
/// </summary>
public enum ScheduledJobStatus
{
    /// <summary>
    /// The job is active and will fire on its configured schedule.
    /// </summary>
    Normal,
    /// <summary>
    /// The job cannot fire because the thread pool has no available threads.
    /// </summary>
    Blocked,
    ...
}
```

---

## 7. Options Classes: Structure, Comments, and Validation

**Flag:** `IOptions<T>` configuration classes missing XML docs, missing environment variable hints in error messages, or using wrong validation attribute types.

**Pattern:** Options classes are `class` (not `record`) with mutable `{ get; set; }` properties for framework binding. They include:
- A `public const string Key` matching the config section name
- XML `/// <summary>` on the class and every property, with usage hints (e.g., example values or valid ranges) inline in the comment
- `[Required]` with an error message that names the environment variable to set (using `__` separator)
- `[Range]` for numeric bounds (not `[Required]` alone)
- No default values — rely on `[Required]` to fail fast

**What to look for:**
```csharp
// ❌ Missing docs, vague error message, no range constraint
public class SchedulingOptions
{
    public const string Key = "Scheduling";

    [Required]
    public string InstanceName { get; set; }

    [Required]
    public int ThreadPoolSize { get; set; }
}

// ✅ Documented, specific error messages with env var names, range validated
/// <summary>
/// Configuration options for Quartz.NET job scheduling
/// </summary>
public class SchedulingOptions
{
    public const string Key = "Scheduling";

    /// <summary>
    /// Unique name for this Quartz scheduler instance (e.g., "AxonScheduler")
    /// </summary>
    [Required(ErrorMessage = "Scheduling InstanceName is required. Set Scheduling__InstanceName environment variable.")]
    public string InstanceName { get; set; }

    /// <summary>
    /// Number of threads in the Quartz thread pool (1–20)
    /// </summary>
    [Required(ErrorMessage = "Scheduling ThreadPoolSize is required. Set Scheduling__ThreadPoolSize environment variable.")]
    [Range(1, 20)]
    public int ThreadPoolSize { get; set; }
}
```

**Rules:**
- Error messages must name the exact environment variable (`Section__Property` format) so misconfiguration is immediately actionable
- Property comments should include the valid range or example value inline — not just restate the property name
- `[Range]` is required for any numeric property with meaningful bounds; `[Required]` alone is not sufficient

---

## 8. Infrastructure Registration: Every Options Class Must Use `AddValidatedOptions`

**Flag:** An `IOptions<T>` class whose values are read via `IConfiguration.GetSection().Get<T>()` during service registration but is never registered through `AddValidatedOptions<T>()`.

**Why wrong:** `GetSection().Get<T>()` binds and reads config but skips `[Required]`, `[Range]`, and `IValidatableObject` validation entirely. A null-guard (`?? throw`) catches only a fully-missing section, not individual missing/invalid fields. `AddValidatedOptions` is the standard path that runs all data-annotation and custom validation at startup.

**What to look for:**
```csharp
// ❌ PersistenceOptions read directly — [Required] fields never validated at startup
services.AddValidatedOptions<SchedulingOptions>(configuration, SchedulingOptions.Key);

var persistenceOptions = configuration
    .GetSection(PersistenceOptions.Key)
    .Get<PersistenceOptions>()
    ?? throw new InvalidOperationException("...");

// ✅ Both options classes go through AddValidatedOptions
services.AddValidatedOptions<SchedulingOptions>(configuration, SchedulingOptions.Key);
services.AddValidatedOptions<PersistenceOptions>(configuration, PersistenceOptions.Key);

var persistenceOptions = configuration
    .GetSection(PersistenceOptions.Key)
    .Get<PersistenceOptions>()
    ?? throw new InvalidOperationException("...");
```

**Note:** The `GetSection().Get<T>()` calls are still necessary when values must be fed into registration-time lambdas (e.g., `AddQuartz`) where DI is not yet available. The null-guard on those reads is a useful safety net. But they do not replace `AddValidatedOptions` — both are needed.

**Rule:** Every options class whose `[Required]`/`[Range]`/`IValidatableObject` rules should be enforced at startup must have a corresponding `AddValidatedOptions<T>()` call, regardless of whether `GetSection().Get<T>()` is also called for registration-time use.
