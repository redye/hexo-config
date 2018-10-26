commitInfo='update'
branch='master'

while getopts "m:b:" arg #选项后面的冒号表示该选项需要参数
do
	case $arg in
		m)
			commitInfo=${OPTARG}
			echo "commit info ${commitInfo}"
			;;
		b)
			branch=${OPTARG}
			;;
		?)
			echo 'NOT KNOW'
			;;
	esac
done

hexo clean
hexo generate
cp -R public/* .deploy/redye.github.io
cd .deploy/redye.github.io
git add .
git commit -m ${commitInfo}
git push origin ${branch}