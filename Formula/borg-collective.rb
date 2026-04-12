class BorgCollective < Formula
  desc "AI development orchestration for parallel Claude Code sessions"
  homepage "https://github.com/noah-goodrich/borg-collective"
  url "https://github.com/noah-goodrich/borg-collective/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "ca4c175f642922f5c3272129d02561f44683f75f432cf6d7dba49a37a37e3b5e"
  license "MIT"

  depends_on "fzf"
  depends_on "jq"

  def install
    libexec.install Dir["*"]

    (bin/"borg").write <<~EOS
      #!/usr/bin/env zsh
      export BORG_HOME="#{libexec}"
      exec "#{libexec}/borg.zsh" "$@"
    EOS

    (bin/"drone").write <<~EOS
      #!/usr/bin/env zsh
      export BORG_HOME="#{libexec}"
      exec "#{libexec}/drone.zsh" "$@"
    EOS
  end

  def caveats
    <<~EOS
      Homebrew installed borg and drone to PATH.

      To register Claude Code hooks and skills, run:
        borg setup

      This is required once per machine. Safe to re-run.
    EOS
  end

  test do
    system bin/"borg", "help"
  end
end
