use std::num::ParseIntError;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};

use target_lexicon::Triple;

use crate::backend::{rules, BackendBuilder, BackendBuilderScope, BuildStep, Rule};
use crate::target::parameters::{DefaultArgument, Files, Flags, Headers};
use crate::target::{Dependency, Language, TArtifactType, Version};
use crate::{traits, Beaver, BeaverError};

pub struct TargetDescriptor<ArtifactType> {
    pub name: String,
    pub description: Option<String>,
    pub homepage: Option<url::Url>,
    pub version: Option<Version>,
    pub license: Option<String>,
    pub language: Language,
    pub sources: Files,
    pub cflags: Flags,
    pub headers: Headers,
    pub linker_flags: Vec<String>,
    pub artifacts: DefaultArgument<Vec<ArtifactType>>,
    pub dependencies: Vec<Dependency>,
    pub settings: Vec<Setting>,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Setting {
    ObjCArc,

    // TO BE IMPLEMENTED!
    CStd(u32),
    CXXStd(u32),
}

#[derive(Debug)]
pub enum SettingParseError {
    NotParseable,
    ExpectedNumber,
    NotANumber(ParseIntError)
}

impl Setting {
    pub fn parse(str: &str) -> Result<Setting, SettingParseError> {
        match str.to_uppercase().as_str() {
            "OBJCARC" | "OBJC-ARC" => Ok(Setting::ObjCArc),
            str if str.starts_with("cstd") => {
                let mut parts = str.split("=");
                _ = parts.next();
                let Some(std) = parts.next() else {
                    return Err(SettingParseError::ExpectedNumber);
                };
                let std = match std.parse::<u32>() {
                    Ok(i) => i,
                    Err(err) => return Err(SettingParseError::NotANumber(err)),
                };
                Ok(Setting::CStd(std))
            },
            str if str.starts_with("cxxstd") || str.starts_with("c++std") => {
                let mut parts = str.split("=");
                _ = parts.next();
                let Some(std) = parts.next() else {
                    return Err(SettingParseError::ExpectedNumber);
                };
                let std = match std.parse::<u32>() {
                    Ok(i) => i,
                    Err(err) => return Err(SettingParseError::NotANumber(err)),
                };
                Ok(Setting::CXXStd(std))
            },
            _ => Err(SettingParseError::NotParseable)
        }
    }
}

pub(crate) trait CTarget: traits::Target {
    type TargetArtifactType: TArtifactType;

    fn user_cflags(&self) -> impl Iterator<Item = &String>;
    /// Both public and private headers
    fn all_headers<'a>(&'a self, project_base_dir: &'a Path) -> impl Iterator<Item = PathBuf> + 'a;

    fn target_artifacts(&self) -> &[Self::TargetArtifactType];

    // TODO: for libraries -> cache cflags and linker_flags
    /// Returns the cflags and files this target depends on
    fn cflags<'a>(
        &self,
        project_base_dir: &Path,
        dependencies: impl Iterator<Item = &'a Dependency>,
        dependency_languages: impl Iterator<Item = &'a Language>,
        context: &Beaver
    ) -> crate::Result<(Vec<String>, Vec<PathBuf>)> {
        let mut add_dependency_files: Vec<PathBuf> = Vec::new();
        let mut cflags: Vec<String> = context.optimize_mode.cflags().iter().map(|s| *s).map(String::from).collect();
        cflags.extend(self.user_cflags().map(|string| string.clone()));
        cflags.extend(self.all_headers(project_base_dir).map(|path| format!("-I{}", path.display())));
        if let Some(langflags) = Language::cflags(self.language(), self.language()) {
            cflags.extend(langflags.iter().map(|str| str.to_string()));
        }

        for dependency in dependencies {
            dependency.public_cflags(context, &mut cflags, &mut add_dependency_files)?;
        }
        for lang in dependency_languages {
            let Some(lang_cflags) = Language::cflags(*lang, self.language()) else { continue };
            cflags.extend(lang_cflags.iter().map(|str| str.to_string()));
        }

        if context.color_enabled() {
            cflags.push("-fdiagnostics-color=always".to_string());
        }

        if (self.language() == Language::OBJC || self.language() == Language::OBJCXX) && self.settings().contains(&Setting::ObjCArc) {
            cflags.push("-fobjc-arc".to_string());
        }

        return Ok((cflags, add_dependency_files));
    }

    // TODO: return iter?
    fn linker_flags<'a>(
        &self,
        dependencies: impl Iterator<Item = &'a Dependency>,
        languages: impl Iterator<Item = &'a Language>,
        triple: &Triple,
        context: &Beaver
    ) -> crate::Result<(Vec<String>, Vec<PathBuf>)>;

    fn settings(&self) -> &[Setting];

    fn register_impl<Builder: BackendBuilder<'static>>(&self,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        builder: Arc<RwLock<Builder>>,
        _scope: &mut Builder::Scope,
        rules: &[&'static Rule],
        context: &crate::Beaver
    ) -> crate::Result<String> {
        let mut guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        for rule in rules {
            guard.add_rule_if_not_exists(rule);
        }

        let mut scope = guard.new_scope();
        drop(guard);

        let dependency_steps = self.dependencies().iter()
            .filter_map(|dep| {
                match dep.ninja_name(context) {
                    Err(err) => Some(Err(err)),
                    Ok(val) => match val {
                        Some(val) => Some(Ok(val)),
                        None => None
                    }
                }
            }).collect::<crate::Result<Vec<String>>>()?;
        let dependency_steps = dependency_steps.iter()
            .map(|str| str.as_str())
            .collect::<Vec<&str>>();

        let (dependencies, languages) = self.unique_dependencies_and_languages_set(context)?;

        let (cflags, additional_dependency_files) = self.cflags(project_base_dir, dependencies.iter(), languages.iter(), context)?;
        let cflags_str = utils::flags::concat_quoted(cflags.into_iter());
        let additional_dependency_files = additional_dependency_files.iter().map(|path: &PathBuf| {
            if let Some(path) = path.to_str() {
                Ok(path)
            } else {
                Err(BeaverError::NonUTF8OsStr(path.as_os_str().to_os_string()))
            }
        }).collect::<crate::Result<Vec<&str>>>()?;

        let (linker_flags, additional_artifact_files) = self.linker_flags(dependencies.iter(), languages.iter(), target_triple, context)?;
        let linker_flags_str = utils::flags::concat_quoted(linker_flags.into_iter());

        let mut artifact_steps: Vec<String> = Vec::new();
        artifact_steps.reserve_exact(self.artifacts().len());

        for artifact in self.target_artifacts() {
            #[cfg(debug_assertions)] {
                scope.add_comment(&format!("{}:{}", self.name(), artifact))?;
            }

            artifact_steps.push(self.register_artifact(
                artifact,
                project_name, project_base_dir, project_build_dir,
                &target_triple,
                &dependency_steps,
                &cflags_str,
                &linker_flags_str,
                &additional_artifact_files,
                &additional_dependency_files,
                &mut scope
            )?);
        }

        let target_step = format!("{}$:{}", project_name, self.name());
        scope.add_step(&BuildStep::Phony {
            name: &target_step,
            args: &artifact_steps.iter().map(|str| str.as_str()).collect::<Vec<&str>>(),
            dependencies: &[]
        })?;

        let mut builder_guard = builder.write()
            .map_err(|err| BeaverError::BackendLockError(err.to_string()))?;
        builder_guard.apply_scope(scope);

        return Ok(target_step);
    }

    fn register_artifact<Scope: BackendBuilderScope>(
        &self,
        artifact: &Self::TargetArtifactType,
        project_name: &str,
        project_base_dir: &Path,
        project_build_dir: &Path,
        target_triple: &Triple,
        dependency_steps: &[&str],
        cflags: &str,
        linker_flags: &str,
        additional_artifact_files: &[PathBuf],
        // Additional files pre-formatted
        additional_dependency_files: &[&str],
        builder: &mut Scope
    ) -> crate::Result<String>;

    fn cc_rule(&self) -> &'static Rule {
        match self.language() {
            Language::C => &rules::CC,
            Language::CXX => &rules::CXX,
            Language::OBJC => &rules::OBJC,
            Language::OBJCXX => &rules::OBJCXX,
            _ => unreachable!("Invalid language for C target")
        }
    }

    fn link_rule(&self) -> &'static Rule {
        match self.language() {
            Language::C => &rules::LINK,
            Language::CXX => &rules::LINKXX,
            Language::OBJC => &rules::LINKOBJC,
            Language::OBJCXX => &rules::LINKOBJCXX,
            _ => unreachable!("Invalid language for C target")
        }
    }

    fn jslib_rule(&self) -> crate::Result<&'static Rule> {
        match self.language() {
            Language::C => Ok(&rules::JSLIB_C),
            Language::CXX => Ok(&rules::JSLIB_CXX),
            _ => return Err(BeaverError::InvalidLanguageForArtifact(self.language(), "jslib"))
        }
    }
}
