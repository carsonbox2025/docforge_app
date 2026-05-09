enum ExportFormat {
  docx('docx', 'Word', '.docx', 'M12 14l9-5-9-5v10z'),
  pdf('pdf', 'PDF', '.pdf', 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'),
  html('html', 'HTML', '.html', 'M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4');

  final String code;
  final String label;
  final String extension;
  final String iconPath;

  const ExportFormat(this.code, this.label, this.extension, this.iconPath);
}
