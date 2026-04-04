class BorgCollective < Formula
  desc "AI development orchestration for parallel Claude Code sessions"
  homepage "https://github.com/noah-goodrich/borg-collective"
  url "https://github.com/noah-goodrich/borg-collective/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "92396a7c53e523979483922c944be1d5d99ad63aca986360b86ca274ba904b7b"
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
