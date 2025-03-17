" Clean and simplified vimrc
" Organized for better readability and compatibility with older Vim versions

" ============================================================================
" BASIC SETTINGS
" ============================================================================
set nocompatible              " Use Vim settings, rather than Vi settings
filetype on                   " Enable filetype detection
filetype plugin on            " Enable loading filetype plugins
filetype indent on            " Enable filetype-specific indenting

" General behavior
set hidden                    " Allow unsaved background buffers
set history=1000              " Remember more commands and search history
set scrolloff=3               " Keep more context when scrolling
set mouse+=a                  " Enable mouse in all modes
set hls                       " Highlight search results
set ignorecase                " Case-insensitive search
set smartcase                 " Unless search contains uppercase
set t_ti= t_te=               " Preserve scrollback buffer
set laststatus=2              " Always show statusline
set shell=bash                " Use bash for shell commands

" Prevent swap/backup files from cluttering directories
" Uncomment and adjust if needed
" set directory=~/.vim/swap//
" set backupdir=~/.vim/backup//
" set undodir=~/.vim/undo//

" ============================================================================
" FILE TYPE SPECIFIC SETTINGS
" ============================================================================
" Indentation settings
autocmd FileType html setlocal shiftwidth=2 tabstop=2 expandtab
autocmd FileType python setlocal shiftwidth=4 tabstop=4 expandtab
autocmd FileType yaml setlocal indentkeys-=<:>

" ============================================================================
" APPEARANCE
" ============================================================================
syntax on                     " Enable syntax highlighting
set t_Co=256                  " Use 256 colors

" Uncomment these if you want line numbers
" set number                    " Show line numbers
" set relativenumber            " Show relative line numbers

" Uncomment to highlight lines longer than 80 columns
" if exists('+colorcolumn')
"   set colorcolumn=80
" else
"   autocmd BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>80v.\+', -1)
" endif

" ============================================================================
" KEYBOARD MAPPINGS
" ============================================================================
" Open files in directory of current file
cnoremap %% <C-R>=expand('%:h').'/'<cr>
map <leader>e :edit %%
map <leader>v :view %%

" Map Ctrl+S to save
command -nargs=0 -bar Update if &modified
            \|  if empty(bufname('%'))
            \|      browse confirm write
            \|  else
            \|      confirm write
            \|  endif
            \|  endif
nnoremap <silent> <C-S> :<C-u>Update<CR>

" Fix backspace behavior in older vim versions
function! Backspace()
  if col('.') == 1
    if line('.')  != 1
      return  "\<ESC>kA\<Del>"
    else
      return ""
    endif
  else
    return "\<Left>\<Del>"
  endif
endfunction
inoremap <BS> <c-r>=Backspace()<CR>

" Regenerate tags
map <F5> :!ctags -R --sort=yes --c++-kinds=+p --fields=+iaS --extra=+q .<CR>
map <F4> :!ctags -R --languages=C++ --c++-kinds=+p --fields=+iaS --extra=+q ./<CR>

" ============================================================================
" CUSTOM COMMANDS
" ============================================================================
" Word count command
function! WC()
    let filename = expand("%")
    let cmd = "detex " . filename . " | wc -w | tr -d [:space:]"
    let result = system(cmd)
    echo result . " words"
endfunction
command! WC call WC()
map <F10> <Esc>:WC<CR>

" MD5 hash of current buffer
command! -range Md5 :echo system('echo '.shellescape(join(getline(<line1>, <line2>), '\n')) . '| md5')

" Insert current timestamp
command! InsertTime :normal a<c-r>=strftime('%F %H:%M:%S.0 %z')<cr>

" ============================================================================
" AUTO COMMANDS
" ============================================================================
" Remove trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

" ============================================================================
" OMNI-COMPLETION (for Vim 7+)
" ============================================================================
if v:version >= 700
  set omnifunc=syntaxcomplete#Complete

  " C++ OmniCppComplete settings
  let OmniCpp_GlobalScopeSearch = 1
  let OmniCpp_DisplayMode = 1
  let OmniCpp_ShowPrototypeInAbbr = 1
  let OmniCpp_ShowAccess = 1
  let OmniCpp_SelectFirstItem = 1
  set completeopt=menuone,menu,longest

  " SuperTab settings (if plugin is installed)
  let g:SuperTabDefaultCompletionType = "<C-X><C-O>"

  " Popup menu colors
  highlight clear
  highlight Pmenu ctermfg=0 ctermbg=2
  highlight PmenuSel ctermfg=0 ctermbg=7
  highlight PmenuSbar ctermfg=7 ctermbg=0
  highlight PmenuThumb ctermfg=0 ctermbg=7
endif

" ============================================================================
" TAGS
" ============================================================================
" Add tag files (uncomment and modify as needed)
" set tags+=~/.vim/tags/cpp
" set tags+=~/.vim/tags/gl
" set tags+=~/.vim/tags/sdl
" set tags+=~/.vim/tags/qt4