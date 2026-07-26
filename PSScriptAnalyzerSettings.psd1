@{
    # Keep interactive UX patterns, but still analyze everything else
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        # Aggregate PwshProfile.psd1 intentionally uses wildcards for backward-compat re-export
        'PSUseToExportFieldsInManifest',
        # Noisy in profile closures and scriptblocks where variable use is indirect
        'PSReviewUnusedParameter',
        # Low signal / informational only
        'PSUseSingularNouns',
        'PSUseOutputTypeCorrectly',
        'PSUseBOMForUnicodeEncodedFile',
        'PSAvoidUsingPositionalParameters',
        'PSPossibleIncorrectComparisonWithNull',
        # Profile helpers declare SupportsShouldProcess for convention without internal ShouldProcess calls
        'PSShouldProcess',
        # 2>$null is intentional stderr suppression, not a comparison operator
        'PSPossibleIncorrectUsageOfRedirectionOperator'
    )

    Rules = @{
        # Enforce ShouldProcess where practical
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $true
        }
    }
}

