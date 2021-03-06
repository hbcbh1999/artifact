//! export command

use dev_prefix::*;
use super::types::*;

use tar::Archive;

use core::utils;

const WEB_STATIC_TAR: &'static [u8] = include_bytes!("data/web-ui-static.tar");

pub fn get_subcommand<'a, 'b>() -> App<'a, 'b> {
    // #SPC-cmd-export
    SubCommand::with_name("export")
        .about("export artifacts as static file (only html currently)")
        .settings(&[AS::DeriveDisplayOrder, COLOR])
        .arg(Arg::with_name("type")
            .help("type of export.\n- html: static html. Writes to `index.html` and `css/` dir \
                   in cwd"))
}

#[derive(Debug)]
pub enum ExportType {
    Html,
}

#[derive(Debug)]
pub struct Cmd {
    ty: ExportType,
}

pub fn get_cmd(matches: &ArgMatches) -> Result<Cmd> {
    let ty = match matches.value_of("type").unwrap_or("").to_ascii_lowercase().as_str() {
        "html" => ExportType::Html,
        t => return Err(ErrorKind::CmdError(format!("unknown type: {}", t)).into()),
    };
    Ok(Cmd { ty: ty })
}

pub fn run_cmd(cwd: &Path, project: &Project, cmd: &Cmd) -> Result<()> {
    match cmd.ty {
        ExportType::Html => {
            // get the artifacts as json and replace with escaped chars
            let data = utils::artifacts_to_json(&project.artifacts, None)
                .replace("\\", "\\\\")
                .replace("'", "\\'");

            // unpack the index.html + css/ files
            let mut archive = Archive::new(WEB_STATIC_TAR);
            if let Err(e) = fs::remove_dir_all(cwd.join("css")) {
                if e.kind() == io::ErrorKind::NotFound {
                } else {
                    return Err(e.into());
                }
            }
            archive.unpack(&cwd).expect("unable to unpack web frontend");
            let index_path = cwd.join("index.html");
            let mut index = fs::OpenOptions::new()
                .read(true)
                .write(true)
                .open(index_path)
                .expect("couldn't open app.js");
            let mut text = String::new();
            index.read_to_string(&mut text).expect("index.html couldn't be read");

            // replace index.html to include the artifacts inline
            index.seek(SeekFrom::Start(0)).unwrap();
            index.set_len(0).unwrap(); // delete what is there
            index.write_all(text.replace("REPLACE_WITH_ARTIFACTS", &data).as_bytes()).unwrap();
            index.flush().unwrap();
        }
    }
    Ok(())
}
