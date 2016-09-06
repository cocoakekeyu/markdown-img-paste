{CompositeDisposable} = require 'atom'
{dirname, join} = require 'path'
clipboard = require 'clipboard'
qiniu = require 'qiniu'
fs = require 'fs'
clipboard = require 'clipboard'

module.exports =
    subscriptions : null

    activate : ->
        @subscriptions = new CompositeDisposable
        @subscriptions.add atom.commands.add 'atom-workspace',
            'markdown-img-paste:paste' : => @paste()

    deactivate : ->
        @subscriptions.dispose()

    paste : ->
        if !cursor = atom.workspace.getActiveTextEditor() then return

        #只在markdown中使用
        if atom.config.get 'markdown-img-paste.only_markdown'
            if !grammar = cursor.getGrammar() then return

            if cursor.getPath()
                if  cursor.getPath().substr(-3) != '.md' and
                    cursor.getPath().substr(-9) != '.markdown' and
                    grammar.scopeName != 'source.gfm'
                        return
            else
                if grammar.scopeName != 'source.gfm' then return

        img = clipboard.readImage()
        if img.isEmpty() then return

        filename = "markdown-img-paste-#{new Date().format()}.png"
        fullname = join(dirname(cursor.getPath()), filename)

        fs.writeFile fullname, img.toPng()

        if !atom.config.get('markdown-img-paste.upload_to_qiniu')
            cursor.insertText '![](' + filename + ')'

        #使用七牛存储图片
        else
            qiniu.conf.ACCESS_KEY = atom.config.get 'markdown-img-paste.zAccessKey'
            qiniu.conf.SECRET_KEY = atom.config.get 'markdown-img-paste.zSecretKey'

            #要上传的空间
            bucket = atom.config.get 'markdown-img-paste.zbucket'

            #七牛空间域名
            domain = atom.config.get 'markdown-img-paste.zdomain'

            #上传到七牛后保存的文件名
            key = filename

            #构建上传策略函数
            uptoken = (bucket, key) ->
                putPolicy = new qiniu.rs.PutPolicy(bucket+":"+key)
                putPolicy.token()

            #生成上传 Token
            token = uptoken bucket, key

            #要上传文件的本地路径
            filePath = fullname

            #构造上传函数
            uploadFile = (uptoken, key, localFile) ->
                extra = new qiniu.io.PutExtra()
                qiniu.io.putFile uptoken, key, localFile, extra, (err, ret) ->
                    if !err
                        #上传成功， 处理返回值
                        #console.log(ret.hash, ret.key, ret.persistentId);
                        atom.notifications.addSuccess 'OK,图片已上传至七牛空间!'
                        fs.unlink fullname, (err) ->
                            if err
                                console.log '未删除本地文件:'+ fullname

                        pastepath =  domain + '/' +  filename
                        cursor.insertText '![](' + pastepath + ')'
                    else
                        #上传失败， 处理返回代码
                        console.log(err);

            #调用uploadFile上传
            uploadFile token, key, filePath

Date.prototype.format = ->

    shift2digits = (val) ->
        if val < 10
            return "0#{val}"
        return val

    year = @getFullYear()
    month = shift2digits @getMonth()+1
    day = shift2digits @getDate()
    hour = shift2digits @getHours()
    minute = shift2digits @getMinutes()
    second = shift2digits @getSeconds()
    ms = shift2digits @getMilliseconds()

    return "#{year}#{month}#{day}#{hour}#{minute}#{second}#{ms}"
