# gcp-audit

The GCP Audit project automates many of the audits found in the Center for Internet Security (CIS) Google Cloud Platform Foundation Benchmark. There is one script per benchmark. The script is named after the corresponding benchmark. The scripts can enumerate all projects in an organization and scan each project, or the user can pass in the project as a parameter.

# Usage Instructions (Cloud Shell)

## Video Tutorial

[**How to Use GCP Audit (Cloud Shell)**](https://www.youtube.com/watch?v=-3GKp9kEcwY)

# Usage Instructions (Local Terminal)

## Video Tutorial

[**How to Use GCP Audit (Local Terminal)**](https://www.youtube.com/watch?v=cnkr_gF7Erg)

## Dependencies

### An operating system to install the needed software

If you would like to use an Ubuntu virtual machine, [**install Ubuntu on VirtualBox**](https://www.youtube.com/watch?v=Cazzls2sZVk) or other hypervisor. Ubuntu runs better on VirtualBox if [**the Guest Additions are installed**](https://www.youtube.com/watch?v=8VCeFRwRmRU). If VirtualBox is not installed, [**install VirtualBox**](https://www.youtube.com/watch?v=61GhP8DsQMw).

### The Google Cloud Platform (GPC) *gcloud* client software

[**This video**](https://www.youtube.com/watch?v=04GONi_U6zU) shows [**how to install the gcloud CLI on Ubuntu Linux**](https://www.youtube.com/watch?v=04GONi_U6zU). Otherwise, follow [**the instructions for your distribution**](https://cloud.google.com/sdk/docs/install#linux)

### This project

`git clone https://github.com/webpwnized/gcp-audit.git`

## Optional Pre-Installation Instructions

1. If you would like to use an Ubuntu virtual machine, [**install Ubuntu on VirtualBox**](https://www.youtube.com/watch?v=Cazzls2sZVk) or other hypervisor. 

2. Ubuntu runs better on VirtualBox if [**the Guest Additions are installed**](https://www.youtube.com/watch?v=AuJGvJoMrgQ). 

3. If VirtualBox is not installed, [**install VirtualBox**](https://www.youtube.com/watch?v=61GhP8DsQMw).

## Contributing

Contributions are welcome! If you'd like to contribute to GCP Audit, please follow these steps:

1. Fork the repository.
2. Create a new branch (\`git checkout -b feature/my-feature\`).
3. Make your changes and commit them (\`git commit -am 'Add new feature'\`).
4. Push to the branch (\`git push origin feature/my-feature\`).
5. Create a new Pull Request.

Please read our [Contribution Guidelines](CONTRIBUTING.md) for more details.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.


