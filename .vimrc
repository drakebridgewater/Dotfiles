" drake bridgewater (not copyrighted, feel free to steal any of it)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" BASIC EDITING CONFIGURATION
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Set color syntax highlighting on
syntax on

" Toggle line counter on/off
set number

" Don't allow mouse to select line numbers when copying
se mouse+=a
set hls

" allow unsaved background buffers and remember marks/undo for them
set hidden

" remember more commands and search history
set history=10000

" make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase

" This makes RVM work inside Vim. I have no idea why.
set shell=bash

"Mark lines over 80 columns
"if exists('+colorcolumn')
"  set colorcolumn=80
"else
"  au BufWinEnter * let w:m2=matchadd('ErrorMsg', '\%>80v.\+', -1)
"endif

" Prevent Vim from clobbering the scrollback buffer. See
" http://www.shallowsky.com/linux/noaltscreen.html
set t_ti= t_te=

" keep more context when scrolling off the end of a buffer
set scrolloff=3

"Spell check!!
setlocal spell spelllang=en_us
map <F6> <Esc>:setlocal spell spelllang=en_us<CR>
map <F7> <Esc>:setlocal nospell<CR>

" Plug in enabling
if v:version >= 600
  filetype plugin on
  filetype indent on
else
  filetype on
endif

"Remove trailing whitespace upon saving
autocmd BufWritePre * :%s/\s\+$//e

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Omnicompletion
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if v:version >= 700
  set omnifunc=syntaxcomplete#Complete " override built-in C omnicomplete with C++ OmniCppComplete plugin
  let OmniCpp_GlobalScopeSearch   = 1
  let OmniCpp_DisplayMode         = 1
  let OmniCpp_ShowScopeInAbbr     = 0 "do not show namespace in pop-up
  let OmniCpp_ShowPrototypeInAbbr = 1 "show prototype in pop-up
  let OmniCpp_ShowAccess          = 1 "show access in pop-up
  let OmniCpp_SelectFirstItem     = 1 "select first item in pop-up
  set completeopt=menuone,menu,longest
endif

"Super tab completion instead of C-X C-O
if version >= 700
  let g:SuperTabDefaultCompletionType = "<C-X><C-O>"
  highlight   clear
  highlight   Pmenu         ctermfg=0 ctermbg=2
  highlight   PmenuSel      ctermfg=0 ctermbg=7
  highlight   PmenuSbar     ctermfg=7 ctermbg=0
  highlight   PmenuThumb    ctermfg=0 ctermbg=7
endif

" Configure tags - add additional tags here or comment out not-used ones
set tags+=~/.vim/tags/cpp
set tags+=~/.vim/tags/gl
set tags+=~/.vim/tags/sdl
set tags+=~/.vim/tags/qt4

" Build tags of your own project
map <F5> :!ctags -R --sort=yes --c++-kinds=+p --fields=+iaS --extra=+q .<CR>

" Update tags (more efficient method)
map <F4> :!ctags -R --languages=C++ --c++-kinds=+p --fields=+iaS --extra=+q ./

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Find file word count
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! WC()
    let filename = expand("%")
    let cmd = "detex " . filename . " | wc -w | tr -d [:space:]"
    let result = system(cmd)
    echo result . " words"
endfunction

command WC call WC()
map <F10> <Esc>:WC<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" CUSTOM AUTOCMDS
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Highlight tabs
autocmd syntax * SpaceHi

"Autocommand for indent settings
  au FileType matlab setl tabstop=2 shiftwidth=2 expandtab
  au FileType html setlocal shiftwidth=2 tabstop=2 expandtab
  au FileType python setl shiftwidth=4 sts=0 tabstop=4 expandtab

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" COLOR
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Coloring!
set t_Co=256

" Color has to be last for some reason
color xoria256

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" OPEN FILES IN DIRECTORY OF CURRENT FILE
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
cnoremap %% <C-R>=expand('%:h').'/'<cr>
map <leader>e :edit %%
map <leader>v :view %%

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Md5 COMMAND
" Show the MD5 of the current buffer
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command! -range Md5 :echo system('echo '.shellescape(join(getline(<line1>, <line2>), '\n')) . '| md5')

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" InsertTime COMMAND
" Insert the current time
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command! InsertTime :normal a<c-r>=strftime('%F %H:%M:%S.0 %z')<cr>


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" (Re?)map Ctrl+S
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
command -nargs=0 -bar Update if &modified
			\|	if empty(bufname('%'))
			\|		browse confirm write
			\|	else
			\|		confirm write
			\|	endif
			\|  endif

nnoremap <silent> <C-S> :<C-u>Update<CR>
