# Development Partnership

We're building production-quality code together. Your role is to create maintainable, efficient solutions while catching potential issues early.

When you seem stuck or overly complex, I'll redirect you - my guidance helps you stay on track.

## 🚨 AUTOMATED CHECKS ARE MANDATORY
**ALL hook issues are BLOCKING - EVERYTHING must be ✅ GREEN!**
No errors. No formatting issues. No linting problems. Zero tolerance.
These are not suggestions. Fix ALL issues before continuing.

## CRITICAL WORKFLOW - ALWAYS FOLLOW THIS!

### Research → Plan → Implement
**NEVER JUMP STRAIGHT TO CODING!** Always follow this sequence:
1. **Research**: Explore the codebase, understand existing patterns
2. **Plan**: Create a detailed implementation plan and verify it with me
3. **Implement**: Execute the plan with validation checkpoints

When asked to implement any feature, you'll first say: "Let me research the codebase and create a plan before implementing."

For complex architectural decisions or challenging problems, use **"ultrathink"** to engage maximum reasoning capacity. Say: "Let me ultrathink about this architecture before proposing a solution."

### USE MULTIPLE AGENTS!
*Leverage subagents aggressively* for better results:

* Spawn agents to explore different parts of the codebase in parallel
* Use one agent to write tests while another implements features
* Delegate research tasks: "I'll have an agent investigate the database schema while I analyze the API structure"
* For complex refactors: One agent identifies changes, another implements them

Say: "I'll spawn agents to tackle different aspects of this problem" whenever a task has multiple independent parts.

### Reality Checkpoints
**Stop and validate** at these moments:
- After implementing a complete feature
- Before starting a new major component
- When something feels wrong
- Before declaring "done"
- **WHEN HOOKS FAIL WITH ERRORS** ❌

> Why: You can lose track of what's actually working. These checkpoints prevent cascading failures.

### 🚨 CRITICAL: Hook Failures Are BLOCKING
**When hooks report ANY issues (exit code 2), you MUST:**
1. **STOP IMMEDIATELY** - Do not continue with other tasks
2. **FIX ALL ISSUES** - Address every ❌ issue until everything is ✅ GREEN
3. **VERIFY THE FIX** - Re-run the failed command to confirm it's fixed
4. **CONTINUE ORIGINAL TASK** - Return to what you were doing before the interrupt
5. **NEVER IGNORE** - There are NO warnings, only requirements

This includes:
- Formatting issues (rubocop, prettier, etc.)
- Linting violations (rubocop, eslint, etc.)
- Forbidden patterns (defined in language-specific rules above)
- ALL other checks

Your code must be 100% clean. No exceptions.

**Recovery Protocol:**
- When interrupted by a hook failure, maintain awareness of your original task
- After fixing all issues and verifying the fix, continue where you left off
- Use the todo list to track both the fix and your original task

## Working Memory Management

### When context gets long:
- Re-read this CLAUDE.md file
- Summarize progress in a PROGRESS.md file
- Document current state before major changes

### Maintain TODO.md:
```
## Current Task
- [ ] What we're doing RIGHT NOW

## Completed
- [x] What's actually done and tested

## Next Steps
- [ ] What comes next
```

## Ruby/Rails-Specific Rules

### FORBIDDEN - NEVER DO THESE:
- **NO** skipping RuboCop rules without team agreement
- **NO** database migrations without proper rollback methods
- **NO** N+1 queries - use includes/preload/eager_load
- **NO** raw SQL without parameterization
- **NO** business logic in views or helpers
- **NO** monkey patching core classes
- **NO** skipping tests for new features

> **AUTOMATED ENFORCEMENT**: The smart-lint hook will BLOCK commits that violate these rules.
> When you see `❌ RUBOCOP VIOLATION`, you MUST fix it immediately!

### Required Standards:
- **Follow RuboCop** configuration strictly
- **RESTful routes** - follow Rails conventions
- **Skinny controllers** - business logic belongs in models/services
- **Strong parameters** - always whitelist permitted attributes
- **Database indexes** - add indexes for foreign keys and frequently queried columns
- **Service objects** - extract complex business logic from models
- **RSpec best practices** - descriptive specs with proper contexts
- **Semantic naming** - `user_id` not `uid`, `EmailService` not `Emailer`

## TypeScript/React-Specific Rules

### FORBIDDEN - NEVER DO THESE:
- **NO any** type - use unknown or proper types
- **NO ts-ignore** - fix the type issue properly
- **NO console.log** in production code
- **NO direct DOM manipulation** - use React's declarative approach
- **NO inline styles** without good reason
- **NO missing dependencies** in useEffect/useMemo/useCallback
- **NO var** - use const/let

> **AUTOMATED ENFORCEMENT**: ESLint and TypeScript compiler will BLOCK commits that violate these rules.
> When you see `❌ ESLINT ERROR` or `❌ TYPE ERROR`, you MUST fix it immediately!

### Required Standards:
- **Strict TypeScript** - enable all strict flags
- **Functional components** - prefer hooks over class components
- **Custom hooks** - extract complex logic into reusable hooks
- **Proper typing** - interfaces for props, explicit return types
- **ESLint compliance** - zero errors, zero warnings
- **Prettier formatting** - consistent code style
- **Accessible components** - proper ARIA labels and semantic HTML
- **Error boundaries** - handle component errors gracefully
- **Memoization** - use React.memo, useMemo, useCallback appropriately

## Implementation Standards

### Our code is complete when:
- ? All linters pass with zero issues
- ? All tests pass
- ? Feature works end-to-end
- ? Old code is deleted
- ? YARD documentation for Ruby or JSDoc/TSDoc for TypeScript

### Testing Strategy
- Complex business logic ? Write tests first
- Simple CRUD ? Write tests after
- Hot paths ? Add benchmarks
- Skip tests for main() and simple CLI parsing

### Ruby/Rails Project Structure
```
app/         # Rails application code
config/      # Configuration files
db/          # Database migrations and schema
spec/        # RSpec tests
lib/         # Custom libraries and tasks
```

### TypeScript/React Project Structure
```
src/         # Source code
  components/  # React components
  hooks/       # Custom React hooks
  services/    # API and business logic
  types/       # TypeScript type definitions
  utils/       # Utility functions
__tests__/   # Test files
```

## Problem-Solving Together

When you're stuck or confused:
1. **Stop** - Don't spiral into complex solutions
2. **Delegate** - Consider spawning agents for parallel investigation
3. **Ultrathink** - For complex problems, say "I need to ultrathink through this challenge" to engage deeper reasoning
4. **Step back** - Re-read the requirements
5. **Simplify** - The simple solution is usually correct
6. **Ask** - "I see two approaches: [A] vs [B]. Which do you prefer?"

My insights on better approaches are valued - please ask for them!

## Performance & Security

### **Measure First**:
- No premature optimization
- Benchmark before claiming something is faster
- Use Ruby profilers (ruby-prof, rack-mini-profiler) or Chrome DevTools for performance analysis

### **Security Always**:
- Validate all inputs
- Use crypto/rand for randomness
- Prepared statements for SQL (never concatenate!)

## Communication Protocol

### Progress Updates:
```
✓ Implemented authentication (all tests passing)
✓ Added rate limiting
✗ Found issue with token expiration - investigating
```

### Suggesting Improvements:
"The current approach works, but I notice [observation].
Would you like me to [specific improvement]?"

## Working Together

- This is always a feature branch - no backwards compatibility needed
- When in doubt, we choose clarity over cleverness
- **REMINDER**: If this file hasn't been referenced in 30+ minutes, RE-READ IT!

Avoid complex abstractions or "clever" code. The simple, obvious solution is probably better, and my guidance helps you stay focused on what matters.
