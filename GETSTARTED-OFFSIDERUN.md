# GetStarted

  What the script does

  - Changes into its own directory, so it works from anywhere.
  - Regenerates the Xcode project with xcodegen if that tool is installed, otherwise uses the existing project.
  - Runs the same simulator build the README documents, with code signing disabled.
  - Opens OffsideRun.xcodeproj in Xcode on success.

  Flags

  ./setup.sh            # build and open in Xcode
  ./setup.sh --no-open  # build only
  ./setup.sh --clean    # wipe Build/DerivedData first

  I also updated the Build section of OffsideRun/README.md to reference the script and removed the stale path pointing at the old jsx-viewer/Offside Run location.

  One thing to flag. The Build/DerivedData folder is committed to git, with about 2400 files. My test build modified or created over 150 of them, so I reverted all of that and the
  working tree now shows only the script and README change. Every run of the script will dirty those files again. Adding Build/ to a .gitignore and untracking it would fix that,
  but I left it alone since that's a bigger change than you asked for. The build also prints stale-file warnings because the committed derived data still references the old path.
  Running ./setup.sh --clean once clears those.

  Nothing is committed yet.
