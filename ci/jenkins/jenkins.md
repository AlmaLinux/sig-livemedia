# Documentation of AlmaLinux Live Media Job

The automation of building of AlmaLinux Live Media images is implemented using Jenkins with two main practices:

- Use Pipeline as a job type.
- Use declarative pipeline domain-specific language (DSL) syntax.

Requirements on Jenkins controller:
- A recent LTS version of Jenkins with default suggested plugins installed. The initial implementation based on `2.414.2`.

Requirements on Jenkins agent:
- `tar`: For creating tarball of log directory.
- `zstd`: For compressing log tarball.
- AWS CLI v2: For uploading artifacts to the AWS bucket.

Pipeline parameters:
- `TYPE_FILTER`: Select a single type or all of the live media images to build. Default values is `ALL`.
- `MINORVER`: Input minor version number of AlmaLinux OS. Default value is 8 for AlmaLinux OS 8.8 and 2 for AlmaLinux OS 9.2.
- `BUCKET`: Input name of the AWS S3 bucket to store build artifacts for public download. Default value is `almalinux-live`.
- `NOTIFY`: A boolean parameter to decide whether to text download URLs of build artifacts to a channel on https://chat.almalinux.org or not.Default is false; do not text.
- `CHANNEL`: Input Name of channel on https://chat.almalinux.org if `NOTIFY` parameter is true. Default is `siglivemedia`. Note: Please, only use channel name from the channel URL. (i.e. `https://chat.almalinux.org/almalinux/channels/siglivemedia`)


To build all live media types in parallel, an one-axis matrix used for not repeating the same stage for each type of live media. It also simplify adding/removing of live media types to the job.

Each live media type has own builder VM, kickstart file, result and log directory, ISO filename and volume ID. To build all of them in parallel or just one of them within single stage (Build), these specifications of live media types are defined inside `liveMediaSpec()` method as:
- `vmName`: Name of builder VM in Vagrantfile.
- `ksFile`: Name of kickstart file.
- `dirName`: Name of directory for build results and logs.
- `isoName`: Name of ISO file.
- `volId`: Volume ID of ISO.

We cat get these values listed below, with providing `TYPE` as a parameter and using of property notation:

```groovy
TYPE = 'GNOME'
def liveMedia = liveMediaSpec(TYPE)
echo "Name of builder VM in Vagrantfile is $liveMedia.vmName"
echo "Name of kickstart file is $liveMedia.ksFile"
echo "Name of directory for build results and logs is $liveMedia.dirName"
echo "Name of ISO file is $liveMedia.isoName"
echo "Volume ID of ISO is $liveMedia.volId"
```

Stages of job:
- `Prepare`: To prepare build environment.
- `CreateMultiBuilders`: To create and configure all builder VMs. Only run when `TYPE_FILTER` job parameter is selected as `ALL`
- `CreateSingleBuilder`: To create and configure single builder VM. Only run when `TYPE_FILTER` job parameter is not selected as `ALL`
- `BuildAndUpload`
    - `Build`: Build the live media images.
    - `Upload`: Upload artifacts to the S3 bucket inside directories created in `YYYYMMDDHHMMSS` format (`2023.09.22 00:42:00`)
- `UploadChecksum`: Upload the checksum of all live media images.

Post section of job:
- Generate Download URLs
    - Show on job output.
    - Text on a channel of chat.almalinux.org if `NOTIFY` is true.
- Cleanup
    - Destroy the builder VMs.
    - Clean the job workspace.

## How to add or remove a live media type

1. Add/Remove the name of live media to/from the `TYPE_FILTER` in `parameters{}`
2. Add/Remove the name of live media to/from the `TYPE` axis in `matrix{}`
3. Add/Remove the URL for ISO and Logs of live media in `msg` , Which is inside the `params.TYPE_FILTER == 'ALL'` condition of `post{}`
4. Add/Remove the specification for the live media in `liveMediaSpec()`
