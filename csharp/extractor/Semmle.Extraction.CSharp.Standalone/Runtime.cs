﻿using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Semmle.BuildAnalyser;
using Semmle.Util;

namespace Semmle.Extraction.CSharp.Standalone
{
    /// <summary>
    /// Locates .NET Runtimes.
    /// </summary>
    internal partial class Runtime
    {
        private const string netCoreApp = "Microsoft.NETCore.App";
        private const string aspNetCoreApp = "Microsoft.AspNetCore.App";

        private readonly DotNet dotNet;
        private static string ExecutingRuntime => RuntimeEnvironment.GetRuntimeDirectory();

        public Runtime(DotNet dotNet) => this.dotNet = dotNet;

        private sealed class RuntimeVersion : IComparable<RuntimeVersion>
        {
            private readonly string dir;
            private Version Version { get; }
            private Version? PreviewVersion { get; } = null;
            private bool IsPreview => PreviewVersion is not null;
            public string FullPath
            {
                get
                {
                    var preview = IsPreview ? $"-preview.{PreviewVersion}" : "";
                    var version = Version + preview;
                    return Path.Combine(dir, version);
                }
            }

            private static Version MakeVersion(string version)
            {
                var versionParts = version.Split('.');
                return new Version(int.Parse(versionParts[0]), int.Parse(versionParts[1]), int.Parse(versionParts[2]));
            }

            public RuntimeVersion(string dir, string version, string previewVersion)
            {
                this.dir = dir;
                Version = MakeVersion(version);
                if (!string.IsNullOrEmpty(previewVersion))
                {
                    PreviewVersion = MakeVersion(previewVersion);
                }
            }

            public int CompareTo(RuntimeVersion? other)
            {
                var c = Version.CompareTo(other?.Version);
                if (c == 0 && IsPreview)
                {
                    return other!.IsPreview ? PreviewVersion!.CompareTo(other!.PreviewVersion) : -1;
                }
                return c;
            }

            public override bool Equals(object? obj) =>
                obj is not null && obj is RuntimeVersion other && other.FullPath == FullPath;

            public override int GetHashCode() => FullPath.GetHashCode();

            public override string ToString() => FullPath;
        }

        [GeneratedRegex(@"^(\S+)\s(\d+\.\d+\.\d+)(-preview\.(\d+\.\d+\.\d+))?\s\[(\S+)\]$")]
        private static partial Regex RuntimeRegex();

        /// <summary>
        /// Parses the output of `dotnet --list-runtimes` to get a map from a runtime to the location of
        /// the newest version of the runtime.
        /// It is assume that the format of a listed runtime is something like:
        /// Microsoft.NETCore.App 7.0.2 [/usr/share/dotnet/shared/Microsoft.NETCore.App]
        /// </summary>
        private static Dictionary<string, RuntimeVersion> ParseRuntimes(IList<string> listed)
        {
            // Parse listed runtimes.
            var runtimes = new Dictionary<string, RuntimeVersion>();
            listed.ForEach(r =>
            {
                var match = RuntimeRegex().Match(r);
                if (match.Success)
                {
                    runtimes.AddOrUpdate(match.Groups[1].Value, new RuntimeVersion(match.Groups[5].Value, match.Groups[2].Value, match.Groups[4].Value));
                }
            });

            return runtimes;
        }

        private Dictionary<string, RuntimeVersion> GetNewestRuntimes()
        {
            var listed = dotNet.GetListedRuntimes();
            return ParseRuntimes(listed);
        }

        /// <summary>
        /// Locates .NET Desktop Runtimes.
        /// This includes Mono and Microsoft.NET.
        /// </summary>
        private static IEnumerable<string> DesktopRuntimes
        {
            get
            {
                var monoPath = FileUtils.FindProgramOnPath(Win32.IsWindows() ? "mono.exe" : "mono");
                var monoDirs = monoPath is not null
                    ? new[] { monoPath }
                    : new[] { "/usr/lib/mono", @"C:\Program Files\Mono\lib\mono" };

                if (Directory.Exists(@"C:\Windows\Microsoft.NET\Framework64"))
                {
                    return Directory.EnumerateDirectories(@"C:\Windows\Microsoft.NET\Framework64", "v*")
                        .OrderByDescending(Path.GetFileName);
                }

                var dir = monoDirs.FirstOrDefault(Directory.Exists);

                if (dir is not null)
                {
                    return Directory.EnumerateDirectories(dir)
                        .Where(d => Char.IsDigit(Path.GetFileName(d)[0]))
                        .OrderByDescending(Path.GetFileName);
                }

                return Enumerable.Empty<string>();
            }
        }

        private IEnumerable<string> GetRuntimes()
        {
            // Gets the newest version of the installed runtimes.
            var newestRuntimes = GetNewestRuntimes();

            // Location of the newest .NET Core Runtime.
            if (newestRuntimes.TryGetValue(netCoreApp, out var netCoreVersion))
            {
                yield return netCoreVersion.FullPath;
            }

            // Location of the newest ASP.NET Core Runtime.
            if (newestRuntimes.TryGetValue(aspNetCoreApp, out var aspNetCoreVersion))
            {
                yield return aspNetCoreVersion.FullPath;
            }

            foreach (var r in DesktopRuntimes)
                yield return r;

            // A bad choice if it's the self-contained runtime distributed in codeql dist.
            yield return ExecutingRuntime;
        }

        /// <summary>
        /// Gets the .NET runtime location to use for extraction
        /// </summary>
        public string GetRuntime(bool useSelfContained) => useSelfContained ? ExecutingRuntime : GetRuntimes().First();
    }
}
