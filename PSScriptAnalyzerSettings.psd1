@{
    # Keep interactive UX patterns, but still analyze everything else
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingInvokeExpression'
    )

    Rules = @{
        # Allow certain non-standard verbs for interactive helpers
        PSUseApprovedVerbs = @{
            # Note: This rule checks verbs; we relax via approved list supplement
            # and accept interactive aliases present in this repo.
            # If functions aren’t Verb-Noun, this rule won’t apply.
            Enable = $true
        }

        # Permit a single global for discoverability of dev project roots
        PSAvoidGlobalVars = @{
            AllowGlobalVars = @('ProjectPaths')
        }

        # Enforce ShouldProcess where practical
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $true
        }
    }
}

