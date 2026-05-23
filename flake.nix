{
  description = "Dynamic Miku Plymouth Theme that rotates clips every boot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      utils,
      nixpkgs,
      ...
    }:
    let
      inherit (utils.lib) eachDefaultSystem;

      defaultClips = [ 0 3 7 10 14 19 24 27 30 36 ];
      allClips = builtins.genList (i: i) 37;

      pad3 =
        n:
        if n < 10 then
          "00${toString n}"
        else if n < 100 then
          "0${toString n}"
        else
          toString n;

      buildTheme =
        pkgs: clips:
        let
          inherit (pkgs) lib;
          clipCount = builtins.length clips;

          clipListLines = lib.concatStringsSep "\n" (
            lib.imap0 (i: id: "clip_list[${toString i}] = ${toString id};") clips
          );
          clipFrameLines = lib.concatStringsSep "\n" (
            lib.imap0 (i: _id: "clip_frames[${toString i}] = 24;") clips
          );
          copyCmds = lib.concatStringsSep "\n" (
            map (id: "cp miku_plymouth_clip_pool/clip${pad3 id}_frame*.png $themeDir/") clips
          );

          plymouthScript = pkgs.writeText "MikuPlymouth.script" ''
            # MikuPlymouth.script — Dynamically Generated for NixOS
            # Artist Credit: Original animations by @x_cast_x on Twitter.
            Window.SetBackgroundTopColor(0, 0, 0);
            Window.SetBackgroundBottomColor(0, 0, 0);

            ${clipListLines}
            ${clipFrameLines}
            total_clips = ${toString clipCount};

            fun pad3(n) {
                if (n < 10) return "00" + n;
                if (n < 100) return "0" + n;
                return "" + n;
            }

            for (i = total_clips - 1; i > 0; i--) {
                j = Math.Int(Math.Random() * (i + 1));
                temp = clip_list[i];
                clip_list[i] = clip_list[j];
                clip_list[j] = temp;
                temp_f = clip_frames[i];
                clip_frames[i] = clip_frames[j];
                clip_frames[j] = temp_f;
            }

            first_id = clip_list[0];
            miku_sprite = Sprite();
            first_img = Image("clip" + pad3(first_id) + "_frame1.png");
            miku_sprite.SetImage(first_img);

            screen.w = Window.GetWidth(0);
            screen.h = Window.GetHeight(0);
            miku_sprite.SetX(Window.GetX() + (screen.w / 2 - first_img.GetWidth() / 2));
            miku_sprite.SetY(Window.GetY() + (screen.h / 2 - first_img.GetHeight() / 2));

            frame_ptr = 0;
            for (c = 0; c < total_clips; c++) {
                t_id = clip_list[c];
                t_frames = clip_frames[c];
                clip_start_idx[c] = frame_ptr;
                for (f = 0; f < t_frames; f++) {
                    img[frame_ptr + f] = Image("clip" + pad3(t_id) + "_frame" + (f + 1) + ".png");
                }
                frame_ptr += t_frames;
            }

            cur_idx = 0;
            progress = 0;

            fun refresh_callback () {
                frame_in_clip = Math.Int(progress / 2.5);
                if (frame_in_clip >= clip_frames[cur_idx])
                    frame_in_clip = clip_frames[cur_idx] - 1;
                miku_sprite.SetImage(img[clip_start_idx[cur_idx] + frame_in_clip]);
                progress++;
                if (progress >= 60 ||
                    frame_in_clip >= clip_frames[cur_idx] - 1 &&
                    progress >= (clip_frames[cur_idx] * 2.5)) {
                    progress = 0;
                    cur_idx = (cur_idx + 1) % total_clips;
                }
            }
            Plymouth.SetRefreshFunction(refresh_callback);

            fun DisplayQuestionCallback(p, e) {}
            Plymouth.SetDisplayQuestionFunction(DisplayQuestionCallback);
            fun DisplayPasswordCallback(n, b) {}
            Plymouth.SetDisplayPasswordFunction(DisplayPasswordCallback);
            fun DisplayNormalCallback() {}
            Plymouth.SetDisplayNormalFunction(DisplayNormalCallback);
            fun MessageCallback(t) {}
            Plymouth.SetMessageFunction(MessageCallback);
          '';
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "miku-plymouth-theme";
          version = "1.0.0";
          src = ./.;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            themeDir=$out/share/plymouth/themes/MikuPlymouth
            mkdir -p $themeDir

            ${copyCmds}

            cp ${plymouthScript} $themeDir/MikuPlymouth.script

            cat > $themeDir/MikuPlymouth.plymouth << EOF
[Plymouth Theme]
Name=MikuPlymouth
Description=Dynamic Miku Plymouth Theme (${toString clipCount} clips)
ModuleName=script

[script]
ImageDir=$themeDir
ScriptFile=$themeDir/MikuPlymouth.script
EOF

            runHook postInstall
          '';
        };

      overlay = final: prev: {
        mikuPlymouth = buildTheme final defaultClips;
        mikuPlymouthFull = buildTheme final allClips;
        mkMikuPlymouth = clips: buildTheme final clips;
      };

      nixosModule =
        { ... }:
        {
          config = {
            nixpkgs.overlays = [ overlay ];
          };
        };
    in
    {
      overlays.default = overlay;
      nixosModules.default = nixosModule;
    }
    // eachDefaultSystem (system: {
      packages =
        let
          pkgs = import nixpkgs { inherit system; };
        in
        rec {
          default = buildTheme pkgs defaultClips;
          full = buildTheme pkgs allClips;
        };
    });
}
