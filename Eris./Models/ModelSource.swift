//
//  ModelSource.swift
//  Eris.
//
//  Introduced in DEV-597 to decouple the domain from MLX.
//

import Foundation
import MLXLMCommon

/// Where an `AIModel` runs and how it is provisioned.
///
/// Discriminated union that lets a second inference backend (Apple
/// Foundation Models, see DEV-598) coexist with MLX without leaking
/// MLX-specific types (`ModelConfiguration`) across the whole domain.
enum ModelSource {
    /// On-device MLX model downloaded from Hugging Face. Carries its
    /// `ModelConfiguration` (repo id, tokenizer, etc.).
    case mlx(ModelConfiguration)

    /// Apple's system on-device model (Foundation Models). No download and
    /// no RAM management — the model already lives in the OS. (DEV-598)
    case appleFoundation
}
