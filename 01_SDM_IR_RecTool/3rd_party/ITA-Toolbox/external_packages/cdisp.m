function cdisp(style,message,varargin)
    % this is now just a wrapper for cprintf in a single line

    cprintf(style, [message '\n'],varargin{:});

end