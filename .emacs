;; Ensure the Option key is used as Meta
(setq mac-option-modifier 'meta)
(setq mac-command-modifier 'super)  ;; Use Command key as Super
(setq mac-control-modifier 'control)

;; Package management setup
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Bootstrap `straight.el`
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Install and configure `openai` package
(straight-use-package
 '(openai :type git :host github :repo "emacs-openai/openai"))

;; Ensure `use-package` is installed
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; Load environment variables
(use-package exec-path-from-shell
  :ensure t
  :config
  (exec-path-from-shell-initialize)
  (exec-path-from-shell-copy-env "OPENAI_API_KEY"))

;; Install basic packages
;; Helm
(use-package helm
  :init (helm-mode 1)
  :bind (("C-x C-f" . helm-find-files)
         ("M-x" . helm-M-x)))

;; Ivy
(use-package ivy
  :init (ivy-mode 1)
  :bind (("C-s" . swiper)
         ("C-x b" . ivy-switch-buffer)))

;; Configure OpenAI
(require 'openai)

;; Debugging: Verify the API key
(setq openai-api-key (getenv "OPENAI_API_KEY"))
(message "OpenAI API Key: %s" openai-api-key)  ;; Print the API key for debugging

(defun openai-ask-question-callback (status &rest args)
  "Callback function to handle the OpenAI API response."
  (when (plist-get status :error)
    (message "Error: %s" (plist-get status :error)))
  (let (response)
    (goto-char url-http-end-of-headers)
    (setq response (buffer-substring-no-properties (point) (point-max)))
    (with-output-to-temp-buffer "*OpenAI Response*"
      (print response))
    (kill-buffer (current-buffer))))

;; Functions to interact with PDFs and OpenAI
(defun extract-text-from-pdf (pdf-file)
  "Extract text from a PDF file using pdfgrep."
  (with-temp-buffer
    (call-process "pdfgrep" nil t nil "-i" "." pdf-file)
    (buffer-string)))

(defun openai-ask-question-from-pdf (pdf-file question)
  "Extract text from a PDF file and send the QUESTION to the OpenAI API."
  (interactive "fPDF file: \nsQuestion: ")
  (let* ((full-text (extract-text-from-pdf pdf-file))
         (highlighted-text "")
         (prompt (concat "Document:\n" full-text "\n\nHighlighted Text:\n" highlighted-text "\n\nQuestion:\n" question))
         (api-key openai-api-key)
         (url "https://api.openai.com/v1/chat/completions")
         (data (json-encode `(("model" . "gpt-4o")
                              ("messages" . [((role . "system") (content . "You are a helpful assistant."))
                                             ((role . "user") (content . ,prompt))]))))
         (url-request-method "POST")
         (url-request-extra-headers `(("Content-Type" . "application/json")
                                      ("Authorization" . ,(concat "Bearer " api-key)))))
    (if (not api-key)
        (message "OpenAI API key is not set")
      (progn
        (message "Request data: %s" data)  ;; Print the request data for debugging
        (url-retrieve url 'openai-ask-question-callback nil data)))))

(global-set-key (kbd "C-c q") 'openai-ask-question-from-pdf)

;; Additional packages and configurations
(use-package counsel
  :after ivy
  :bind (("M-x" . counsel-M-x)
         ("C-x C-f" . counsel-find-file)))

(use-package projectile
  :init (projectile-mode 1)  ; Corrected from projectjectile-mode to projectile-mode
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :config
  (setq projectile-completion-system 'ivy))

(use-package magit
  :bind (("C-x g" . magit-status)))

(use-package doom-themes
  :config
  (load-theme 'doom-one t))

(use-package pdf-tools
  :config
  (pdf-tools-install)
  (add-hook 'pdf-view-mode-hook 'auto-revert-mode))

(add-to-list 'auto-mode-alist '("\\.pdf\\'" . pdf-view-mode))

(global-set-key (kbd "M-x") 'counsel-M-x)
(global-set-key (kbd "C-s") 'swiper)
(global-set-key (kbd "C-x g") 'magit-status)
